import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/ads_analytics_service.dart';
import '../theme/app_theme.dart';

/// Native ad jo content cards jaisa dikhta hai — "Sponsored" badge ke
/// saath. Pool se instant ad milta hai, nahi toh fresh load hota hai.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, this.aspectRatio = 2 / 3, required this.placement});

  final double aspectRatio;
  final String placement;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    await AdService.instance.isReady;
    if (!mounted) return;

    // Try pool first — zero wait
    _ad = AdService.instance.takeNative(placement: widget.placement);
    if (_ad != null && mounted) {
      setState(() => _loaded = true);
      return;
    }

    // Fallback — fresh load with combined listener
    _ad = NativeAd(
      adUnitId: AdService.testNativeUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _loaded = true);
            AdsAnalyticsService.instance.logImpression(adType: 'native', placement: widget.placement);
          } else {
            ad.dispose();
          }
        },
        onAdClicked: (ad) {
          AdsAnalyticsService.instance.logClick(adType: 'native', placement: widget.placement);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAdCard: failed: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
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
    if (!_loaded || _ad == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.mdRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: AdWidget(ad: _ad!),
          ),
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: AppRadius.smRadius,
              ),
              child: const Text(
                'Sponsored',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
