import 'icon_pack_service.dart';
import 'native_bridge_service.dart';

/// Ek app entry: package name, label, aur icon-pack lookup ke liye keyword.
/// [iconKey] nullable hai -- device par installed har app hamare 10
/// bundled categories (browser/calculator/...) mein fit nahi hoti, aisi
/// apps ke liye bundled tabs par sirf generic fallback icon dikhega.
class AppEntry {
  final String packageName;
  final String label;
  final String? iconKey;
  const AppEntry(this.packageName, this.label, this.iconKey);
}

/// Shared icon-matching logic — dono IconChangerScreen aur ThemeController
/// isi ek jagah se guess karte hain ke kis app ke liye bundled pack mein
/// kaunsa icon match hota hai, taake dono jagah ka result hamesha same rahe.
class IconMatchingService {
  IconMatchingService._();
  static final IconMatchingService instance = IconMatchingService._();

  /// Bundled (pre-made) icon packs -- matches assets/icon_packs/<id>/
  /// folder structure. Ye teeno "edit" nahi ho sakte -- fixed/curated
  /// packs hain.
  static const List<String> bundledIconPacks = ['cartoon', 'flat_colors', 'dark_mode'];

  /// Available icon keys in bundled packs -- sirf in keys ke liye actual
  /// PNG files exist. Agar guessIconKey kisi aur key return kare (jaise
  /// 'whatsapp', 'facebook' etc.), to shortcut creation skip karna chahiye
  /// kyunki unke assets nahi hain.
  static const Set<String> availableBundledKeys = {
    'browser',
    'calculator',
    'calendar',
    'camera',
    'clock',
    'contacts',
    'gallery',
    'messages',
    'phone',
    'settings',
  };

  /// Curated exact-package mapping -- well-known apps (WhatsApp, Instagram,
  /// etc.) ko unka apna distinct iconKey milta hai, generic category-guess
  /// ki wajah se ek jaisa shared icon nahi milta. Ye check hamesha
  /// keyword-guess se PEHLE hota hai.
  ///
  /// NOTE -- asset status: filhaal sirf 10 keys ke PNGs bundled hain
  /// (browser/calculator/calendar/camera/clock/contacts/gallery/messages/
  /// phone/settings). Neeche wale naye keys ke liye tab tak generic
  /// fallback icon hi dikhega jab tak assets/icon_packs/<pack>/<key>.png
  /// add na ki jaaye -- crash nahi hoga.
  static const Map<String, String> curatedPackageIconKeys = {
    // Popular apps
    'com.whatsapp': 'whatsapp',
    'com.whatsapp.w4b': 'whatsapp',
    'com.facebook.orca': 'messenger',
    'com.facebook.katana': 'facebook',
    'com.facebook.lite': 'facebook',
    'com.instagram.android': 'instagram',
    'com.google.android.youtube': 'youtube',
    'org.telegram.messenger': 'telegram',
    'com.google.android.gm': 'gmail',
    'com.snapchat.android': 'snapchat',
    'com.zhiliaoapp.musically': 'tiktok',
    'com.ss.android.ugc.trill': 'tiktok',
    'com.twitter.android': 'x',
    'com.spotify.music': 'spotify',
    'com.netflix.mediaclient': 'netflix',

    // Samsung system apps (common on Samsung devices/emulators)
    'com.samsung.android.messaging': 'messages',
    'com.samsung.android.app.contacts': 'contacts',
    'com.samsung.android.gallery3d': 'gallery',
    'com.sec.android.app.camera': 'camera',
    'com.sec.android.app.clockpackage': 'clock',
    'com.samsung.android.calendar': 'calendar',
    'com.sec.android.app.dialer': 'phone',
    'com.android.chrome': 'browser',
    'com.android.settings': 'settings',

    // Google system apps (common on stock Android/emulators)
    'com.google.android.apps.messaging': 'messages',
    'com.android.mms': 'messages',
    'com.android.contacts': 'contacts',
    'com.google.android.apps.photos': 'gallery',
    'com.android.gallery3d': 'gallery',
    'com.android.camera2': 'camera',
    'com.android.camera': 'camera',
    'com.android.deskclock': 'clock',
    'com.android.calendar': 'calendar',
    'com.android.dialer': 'phone',
    'com.android.browser': 'browser',

    // Calculator apps
    'com.android.calculator2': 'calculator',
    'com.sec.android.app.popupcalculator': 'calculator',

    // Other common system apps
    'com.android.providers.downloads': 'browser',
    'com.android.filemanager': 'gallery',
  };

  /// Bundled icon packs sirf 10 fixed keywords cover karte hain. Real
  /// device par installed kisi bhi app ke liye package name + label me in
  /// keywords ko dhoond kar best-guess iconKey nikalta hai. Match na mile
  /// to null.
  String? guessKeywordIconKey(String packageName, String label) {
    final p = packageName.toLowerCase();
    final l = label.toLowerCase();
    bool has(List<String> needles) =>
        needles.any((n) => p.contains(n) || l.contains(n));

    if (has(['chrome', 'browser', 'firefox', 'internet', 'webview'])) return 'browser';
    if (has(['calculator', 'calc'])) return 'calculator';
    if (has(['calendar'])) return 'calendar';
    if (has(['camera'])) return 'camera';
    if (has(['clock', 'deskclock', 'alarm'])) return 'clock';
    if (has(['contacts', 'people'])) return 'contacts';
    if (has(['gallery', 'photos', 'album', 'gallery3d'])) return 'gallery';
    if (has(['messag', 'sms', 'mms'])) return 'messages';
    if (has(['dialer', 'incallui']) || l == 'phone') return 'phone';
    if (has(['settings'])) return 'settings';
    return null;
  }

  /// Final iconKey resolver (bundled tabs ke liye): pehle curated
  /// exact-package table check hoti hai, tabhi na mile to generic
  /// keyword-category guess pe fallback hota hai. Sirf wahi key return
  /// hota hai jiska actual bundled asset available hai.
  String? guessIconKey(String packageName, String label) {
    final key = curatedPackageIconKeys[packageName] ?? guessKeywordIconKey(packageName, label);
    // Sirf wahi key return karo jiska asset actually bundled hai
    return (key != null && availableBundledKeys.contains(key)) ? key : null;
  }

  /// [packId] mein [iconKey] ke liye bundled asset resolve karke uska
  /// Home Screen shortcut request bhejta hai. Returns true sirf tab jab
  /// Android ne shortcut request accept kar li ho.
  ///
  /// Throws nahi karta apne andar se catch — caller (batch apply) ko khud
  /// har call try/catch mein wrap karna chahiye, taake ek app ka fail hona
  /// baaki apps ko na roke.
  Future<bool> applyBundledIconShortcut({
    required String packId,
    required String packageName,
    required String appLabel,
    required String iconKey,
  }) async {
    final assetPath = IconPackService.instance.bundledAssetPath(packId, iconKey);
    final filePath = await IconPackService.instance.assetToFile(assetPath, packageName);
    return NativeBridgeService.instance.createIconShortcut(
      packageName: packageName,
      appLabel: appLabel,
      iconFilePath: filePath,
    );
  }
}