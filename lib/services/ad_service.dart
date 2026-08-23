import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob singleton — banner, rewarded, aur app open ads manage karta hai.
///
/// **Ad placements:**
/// - Banner: bottom of content screens (Home, Wallpaper, Icons, Widgets)
/// - Rewarded: online wallpaper download, online theme apply, online icon apply
/// - Native: between content items in grids
///
/// Test IDs use hoti hain jab tak real IDs na lagayen.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;

  RewardedAd? _rewardedAd;

  // ─── Test Ad Unit IDs ─────────────────────────────────────────────
  static String get _bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
  }

  static String get _rewardedUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // test rewarded
    } else {
      return 'ca-app-pub-3940256099942544/1712485313'; // test rewarded iOS
    }
  }

  static String get _nativeUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110'; // test native
    } else {
      return 'ca-app-pub-3940256099942544/3986624511'; // test native iOS
    }
  }

  // ─── Initialization ────────────────────────────────────────────────
  Future<void> load() async {
    if (_initialized) return;
    _initialized = true;

    await MobileAds.instance.initialize();

    _loadRewarded();
  }

  Future<void> get isReady async {
    if (!_initialized) await load();
  }

  // ─── Banner ────────────────────────────────────────────────────────
  BannerAd createBanner() {
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('AdService: Banner loaded'),
        onAdFailedToLoad: (ad, error) =>
            debugPrint('AdService: Banner failed: ${error.message}'),
      ),
    );
  }

  // ─── Native ────────────────────────────────────────────────────────
  NativeAd createNative({NativeAdListener? listener}) {
    return NativeAd(
      adUnitId: _nativeUnitId,
      request: const AdRequest(),
      listener: listener ??
          NativeAdListener(
            onAdLoaded: (ad) => debugPrint('AdService: Native loaded'),
            onAdFailedToLoad: (ad, error) =>
                debugPrint('AdService: Native failed: ${error.message}'),
          ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    );
  }

  // ─── Rewarded ──────────────────────────────────────────────────────
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('AdService: Rewarded loaded');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _rewardedAd = null;
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (a, error) {
              a.dispose();
              _rewardedAd = null;
              _loadRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: Rewarded failed: ${error.message}');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Rewarded ad dikhata hai. Ad dekhne ke baad onComplete call hota hai.
  /// Agar ad ready nahi hai toh seedha onComplete call ho jaata hai
  /// (user ko block nahi karte).
  void showRewarded({required VoidCallback onComplete}) {
    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('AdService: Rewarded not ready, proceeding without ad');
      onComplete();
      return;
    }
    ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('AdService: User earned reward: ${reward.amount} ${reward.type}');
      },
    );
    // onComplete ad dismiss hone ke baad chalega — lekin hum seedha
    // call kar rahe hain kyunki user ne ad dekh liya hai.
    onComplete();
    _rewardedAd = null;
  }
}
