import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

/// Native ad jo content cards jaisa dikhta hai — "Sponsored" badge ke
/// saath. HomeScreen aur WallpaperScreen category grids mein use hota hai.
///
/// `aspectRatio` param se surrounding cards ke saath match karwa sakte
/// ho (e.g. 2/3 for wallpaper grid, wider for full-width list cards).
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, this.aspectRatio = 2 / 3});

  final double aspectRatio;

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

  Future<void> _loadAd() async {
    await AdService.instance.isReady;
    if (!mounted) return;
    _ad = AdService.instance.createNative(
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAdCard: failed: ${error.message}');
          ad.dispose();
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
    if (!_loaded || _ad == null) {
      return const SizedBox.shrink();
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
