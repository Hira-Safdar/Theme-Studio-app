import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob singleton — banner, interstitial, aur app open ads manage karta
/// hai. Test IDs use hoti hain jab tak real IDs na lagayen.
///
/// **Singleton pattern**: `AdService.instance.load()` main.dart mein
/// initState mein call hota hai. Baaki screens `AdService.instance`
/// access karti hain.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initialized = false;
  bool _interstitialReady = false;
  bool _appOpenReady = false;

  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;

  // ─── Test Ad Unit IDs ─────────────────────────────────────────────
  // Real IDs publish karte waqt badal lena.
  static String get _bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // test banner
    } else {
      return 'ca-app-pub-3940256099942544/2934735716'; // test banner iOS
    }
  }

  static String get _interstitialUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // test interstitial
    } else {
      return 'ca-app-pub-3940256099942544/4411468910'; // test interstitial iOS
    }
  }

  static String get _appOpenUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/9257395921'; // test app open
    } else {
      return 'ca-app-pub-3940256099942544/5580651370'; // test app open iOS
    }
  }

  // ─── Initialization ────────────────────────────────────────────────
  Future<void> load() async {
    if (_initialized) return;
    _initialized = true;

    await MobileAds.instance.initialize();

    _loadInterstitial();
    _loadAppOpen();
  }

  // ─── Banner ────────────────────────────────────────────────────────
  /// Har screen ke neeche (nav bar ke upar) ek banner dikhane ke liye.
  /// Caller ko BannerAd wapas milta hai, usse dispose karna caller ka
  /// kaam hai (usually Screen dispose mein).
  BannerAd createBanner() {
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdService: Banner failed: ${error.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  // ─── Interstitial ──────────────────────────────────────────────────
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _interstitialReady = false;
              _loadInterstitial(); // next ke liye pre-load
            },
            onAdFailedToShowFullScreenContent: (a, error) {
              a.dispose();
              _interstitialReady = false;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: Interstitial failed: ${error.message}');
          _interstitialReady = false;
        },
      ),
    );
  }

  /// Transition point par dikhata hai — wallpaper apply, theme apply,
  /// icon apply ke baad. Agar ad ready nahi hai toh silently skip.
  void showInterstitialIfReady() {
    if (_interstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  // ─── App Open ──────────────────────────────────────────────────────
  void _loadAppOpen() {
    AppOpenAd.load(
      adUnitId: _appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _appOpenReady = false;
              _loadAppOpen();
            },
            onAdFailedToShowFullScreenContent: (a, error) {
              a.dispose();
              _appOpenReady = false;
              _loadAppOpen();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: AppOpen failed: ${error.message}');
          _appOpenReady = false;
        },
      ),
    );
  }

  /// App foreground par aaye toh dikhata hai. Sirf ek dafa, har resume
  /// par nahi — 4 hour cooldown rakhta hai taake user frustrate na ho.
  DateTime? _lastAppOpenShown;
  static const _appOpenCooldown = Duration(hours: 4);

  void showAppOpenIfReady() {
    if (!_appOpenReady || _appOpenAd == null) return;
    if (_lastAppOpenShown != null &&
        DateTime.now().difference(_lastAppOpenShown!) < _appOpenCooldown) {
      return;
    }
    _lastAppOpenShown = DateTime.now();
    _appOpenAd!.show();
  }
}
