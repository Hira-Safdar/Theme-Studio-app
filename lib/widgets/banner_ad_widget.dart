import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/ads_analytics_service.dart';
import '../theme/app_theme.dart';

/// Reusable banner ad widget — pool se instant ad milta hai,
/// nahi toh fresh load hota hai. Loading mein placeholder, failure mein
/// terminal state (no infinite spinner).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key, required this.placement});

  final String placement;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    await AdService.instance.isReady;
    if (!mounted) return;

    // Try pool first — zero wait
    _ad = AdService.instance.takeBanner(placement: widget.placement);
    if (_ad != null && mounted) {
      setState(() => _loaded = true);
      return;
    }

    // Fallback — fresh load with combined listener (logging + setState)
    _ad = BannerAd(
      adUnitId: AdService.testBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
          AdsAnalyticsService.instance.logImpression(adType: 'banner', placement: widget.placement);
        },
        onAdClicked: (ad) {
          AdsAnalyticsService.instance.logClick(adType: 'banner', placement: widget.placement);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAdWidget: load error ${error.message}');
          ad.dispose();
          if (mounted) setState(() { _ad = null; _failed = true; });
        },
      ),
    );
    _ad!.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox.shrink();
    }
    if (!_loaded || _ad == null) {
      return Container(
        width: AdSize.banner.width.toDouble(),
        height: AdSize.banner.height.toDouble(),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.smRadius,
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
