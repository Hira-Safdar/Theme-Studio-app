import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads_analytics_service.dart';

/// AdMob singleton — pool-based cache for instant ad display.
///
/// **Preload strategy:**
/// - Splash pe: SDK init + 4 banner + 8 native + 1 rewarded parallel load
/// - Har slot ke liye ek cached ad ready — zero wait on screen open
/// - Consume hotay hi next ad automatically refill hota hai
/// - App resume pe pools refresh hote hain (sirf 5+ sec background ho toh)
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;

  // ─── Pool sizes ───────────────────────────────────────────────────
  static const int _bannerPoolSize = 4;
  static const int _nativePoolSize = 8;

  // ─── Pools ────────────────────────────────────────────────────────
  final List<BannerAd> _bannerPool = [];
  final List<NativeAd> _nativePool = [];
  RewardedAd? _rewardedAd;
  bool _rewardedLoading = false;

  // ─── Loading states ──────────────────────────────────────────────
  final Set<int> _bannerLoading = {};
  final Set<int> _nativeLoading = {};

  // ─── Retry backoff ────────────────────────────────────────────────
  int _bannerRetryDelay = 3;
  int _nativeRetryDelay = 3;
  int _rewardedRetryDelay = 3;
  static const int _maxRetryDelay = 30;

  // ─── Background throttle ──────────────────────────────────────────
  DateTime? _lastBackgroundTime;

  // ─── Test Ad Unit IDs (public for fallback) ──────────────────────
  static String get testBannerUnitId => _bannerUnitId;
  static String get testNativeUnitId => _nativeUnitId;

  static String get _bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
  }

  static String get _rewardedUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
  }

  static String get _nativeUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110';
    } else {
      return 'ca-app-pub-3940256099942544/3986624511';
    }
  }

  // ─── Initialization ────────────────────────────────────────────────
  Future<void> load() async {
    if (_initialized) return;
    _initialized = true;

    await MobileAds.instance.initialize();

    for (int i = 0; i < _bannerPoolSize; i++) {
      _preloadBannerSlot(i);
    }
    for (int i = 0; i < _nativePoolSize; i++) {
      _preloadNativeSlot(i);
    }
    _loadRewarded();
  }

  Future<void> get isReady async {
    if (!_initialized) await load();
  }

  /// App resume pe — sirf tab refresh karo jab 5+ sec background raha ho.
  void refreshPools() {
    final now = DateTime.now();
    final bg = _lastBackgroundTime;
    if (bg != null && now.difference(bg).inSeconds < 5) {
      ensureRewardedReady();
      return; // bahut chhota gap — skip pool refresh
    }
    _lastBackgroundTime = now;

    debugPrint('AdService: Refreshing pools on resume');
    for (final ad in _bannerPool) {
      ad.dispose();
    }
    _bannerPool.clear();
    for (final ad in _nativePool) {
      ad.dispose();
    }
    _nativePool.clear();

    _bannerRetryDelay = 3;
    _nativeRetryDelay = 3;
    for (int i = 0; i < _bannerPoolSize; i++) {
      _preloadBannerSlot(i);
    }
    for (int i = 0; i < _nativePoolSize; i++) {
      _preloadNativeSlot(i);
    }
    _loadRewarded();
  }

  // ═══════════════════════════════════════════════════════════════════
  // BANNER — pool of 4, auto-refill on consume
  // ═══════════════════════════════════════════════════════════════════
  BannerAd createBanner({required String placement}) {
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdService: Banner loaded [$placement]');
          AdsAnalyticsService.instance.logImpression(adType: 'banner', placement: placement);
        },
        onAdClicked: (ad) {
          AdsAnalyticsService.instance.logClick(adType: 'banner', placement: placement);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdService: Banner failed: ${error.message}');
          ad.dispose();
        },
      ),
    );
  }

  void _preloadBannerSlot(int index) {
    if (_bannerLoading.contains(index)) return;
    _bannerLoading.add(index);

    BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _bannerPool.add(ad as BannerAd);
          _bannerLoading.remove(index);
          _bannerRetryDelay = 3;
          debugPrint('AdService: Banner pool[$index] ready (${_bannerPool.length}/$_bannerPoolSize)');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerLoading.remove(index);
          debugPrint('AdService: Banner pool[$index] failed: ${error.message}');
          final delay = Duration(seconds: _bannerRetryDelay);
          _bannerRetryDelay = (_bannerRetryDelay * 2).clamp(3, _maxRetryDelay);
          Future.delayed(delay, () => _preloadBannerSlot(index));
        },
      ),
    ).load();
  }

  /// Pool se banner lo. Consume hone pe turant next preload start hota hai.
  BannerAd? takeBanner({required String placement}) {
    if (_bannerPool.isNotEmpty) {
      final ad = _bannerPool.removeAt(0);
      debugPrint('AdService: Banner served from pool [$placement] (${_bannerPool.length} remaining)');
      AdsAnalyticsService.instance.logImpression(adType: 'banner', placement: placement);
      // Auto-refill: turant naya ad load karo
      _preloadBannerSlot(_bannerPool.length);
      return ad;
    }
    debugPrint('AdService: Banner pool empty [$placement]');
    return null;
  }

  int get bannerPoolSize => _bannerPool.length;

  // ═══════════════════════════════════════════════════════════════════
  // NATIVE — pool of 8, auto-refill on consume
  // ═══════════════════════════════════════════════════════════════════
  NativeAd createNative({required String placement, NativeAdListener? listener}) {
    return NativeAd(
      adUnitId: _nativeUnitId,
      request: const AdRequest(),
      listener: listener ??
          NativeAdListener(
            onAdLoaded: (ad) {
              debugPrint('AdService: Native loaded [$placement]');
              AdsAnalyticsService.instance.logImpression(adType: 'native', placement: placement);
            },
            onAdClicked: (ad) {
              AdsAnalyticsService.instance.logClick(adType: 'native', placement: placement);
            },
            onAdFailedToLoad: (ad, error) {
              debugPrint('AdService: Native failed: ${error.message}');
              ad.dispose();
            },
          ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    );
  }

  void _preloadNativeSlot(int index) {
    if (_nativeLoading.contains(index)) return;
    _nativeLoading.add(index);

    NativeAd(
      adUnitId: _nativeUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _nativePool.add(ad as NativeAd);
          _nativeLoading.remove(index);
          _nativeRetryDelay = 3;
          debugPrint('AdService: Native pool[$index] ready (${_nativePool.length}/$_nativePoolSize)');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeLoading.remove(index);
          debugPrint('AdService: Native pool[$index] failed: ${error.message}');
          final delay = Duration(seconds: _nativeRetryDelay);
          _nativeRetryDelay = (_nativeRetryDelay * 2).clamp(3, _maxRetryDelay);
          Future.delayed(delay, () => _preloadNativeSlot(index));
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    ).load();
  }

  /// Pool se native lo. Consume hone pe turant next preload start hota hai.
  NativeAd? takeNative({required String placement}) {
    if (_nativePool.isNotEmpty) {
      final ad = _nativePool.removeAt(0);
      debugPrint('AdService: Native served from pool [$placement] (${_nativePool.length} remaining)');
      AdsAnalyticsService.instance.logImpression(adType: 'native', placement: placement);
      // Auto-refill: turant naya ad load karo
      _preloadNativeSlot(_nativePool.length);
      return ad;
    }
    debugPrint('AdService: Native pool empty [$placement]');
    return null;
  }

  int get nativePoolSize => _nativePool.length;

  // ═══════════════════════════════════════════════════════════════════
  // REWARDED — always preloaded (single) + exponential backoff
  // ═══════════════════════════════════════════════════════════════════
  void _loadRewarded() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedAd = ad;
          _rewardedRetryDelay = 3;
          debugPrint('AdService: Rewarded preloaded');
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
          _rewardedLoading = false;
          debugPrint('AdService: Rewarded failed: ${error.message}');
          _rewardedAd = null;
          final delay = Duration(seconds: _rewardedRetryDelay);
          _rewardedRetryDelay = (_rewardedRetryDelay * 2).clamp(3, _maxRetryDelay);
          Future.delayed(delay, _loadRewarded);
        },
      ),
    );
  }

  void ensureRewardedReady() {
    if (_rewardedAd == null && !_rewardedLoading) {
      debugPrint('AdService: Pre-loading rewarded ad');
      _loadRewarded();
    }
  }

  /// Rewarded ad dikhata hai.
  ///
  /// - [onComplete] sirf tab call hota hai jab user reward earn kare.
  /// - [onUnavailable] tab call hota hai jab ad ready na ho (free pass).
  /// - [onDismissed] tab call hota hai jab user ad dekh ke dismiss kare
  ///   bina reward ke (early close).
  void showRewarded({
    required String placement,
    required VoidCallback onComplete,
    VoidCallback? onUnavailable,
    VoidCallback? onDismissed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint('AdService: Rewarded not ready, free pass [$placement]');
      AdsAnalyticsService.instance.logRewardedFreePass(placement: placement);
      onComplete();
      onUnavailable?.call();
      return;
    }

    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        debugPrint('AdService: Rewarded showed [$placement]');
        AdsAnalyticsService.instance.logImpression(adType: 'rewarded', placement: placement);
      },
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!rewardEarned) {
          debugPrint('AdService: Rewarded dismissed without reward [$placement]');
          onDismissed?.call();
        }
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        debugPrint('AdService: Rewarded show failed: ${error.message}');
        a.dispose();
        _rewardedAd = null;
        _loadRewarded();
        onDismissed?.call();
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('AdService: User earned reward: ${reward.amount} ${reward.type}');
        AdsAnalyticsService.instance.logRewardedCompleted(placement: placement);
        rewardEarned = true;
        onComplete();
      },
    );
    _rewardedAd = null;
  }
}
