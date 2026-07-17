import 'dart:io';
import 'package:flutter/foundation.dart'; // debugPrint ke liye
import 'package:flutter/services.dart';

/// Device par real installed (launchable) app ka minimal record --
/// [getInstalledApps] se aata hai. Iconography ka koi concept yahan nahi,
/// wo UI layer (icon_changer_screen.dart) khud label/package se guess
/// karta hai, kyunke bundled icon packs sirf 10 fixed categories cover
/// karte hain.
class InstalledApp {
  final String packageName;
  final String label;
  const InstalledApp({required this.packageName, required this.label});
}

/// Ye class Flutter <-> Kotlin ke beech saara MethodChannel communication
/// handle karti hai. Naam se hi clear hai: "native se pull ya push" jo bhi
/// karna ho, yahin se ho.
class NativeBridgeService {
  NativeBridgeService._();
  static final NativeBridgeService instance = NativeBridgeService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.theme_studio/native');

  // ---------------- WALLPAPER ----------------

  /// [imagePath] ek real file-system path hona chahiye (asset nahi).
  /// [target] = "home", "lock", ya "both"
  Future<bool> setWallpaper(String imagePath, {String target = 'both'}) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setWallpaper', {
        'path': imagePath,
        'target': target,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Wallpaper set failed: ${e.message}');
      return false;
    }
  }

  // ---------------- ICON SHORTCUT ----------------

  /// Installed app ka asal (current) launcher icon PNG bytes ke tor par
  /// laata hai -- Icon Changer screen ke "before -> after" preview ke liye.
  /// App uninstalled ho ya koi aur error aaye to null milega -- UI ko
  /// khud fallback (generic icon) dikhana chahiye.
  Future<Uint8List?> getAppIcon(String packageName) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('getAppIcon failed for $packageName: ${e.message}');
      return null;
    }
  }

  /// [packageName] jis app ka icon replace karna hai (e.g. "com.whatsapp")
  /// [appLabel] Home Screen par dikhne wala naam
  /// [iconFilePath] ek real PNG file ka path (asset ya custom, dono ko
  /// pehle IconPackService se file path me convert karna hoga)
  ///
  /// NOTE: Ye system ka "Add to Home Screen" confirmation dialog dikhayega.
  /// User ko manually confirm karna padega -- ye Android security policy hai,
  /// isko skip nahi kiya ja sakta.
  Future<bool> createIconShortcut({
    required String packageName,
    required String appLabel,
    required String iconFilePath,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('createShortcut', {
        'packageName': packageName,
        'appLabel': appLabel,
        'iconPath': iconFilePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Shortcut creation failed: ${e.message}');
      return false;
    }
  }

  Future<bool> isPinShortcutSupported() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>('isPinShortcutSupported');
    return result ?? false;
  }

  /// Device par jitni bhi "launchable" apps installed hain unki real list
  /// (package name + label) -- demoApps ki jagah ye use hoti hai, taake
  /// Samsung/Infinix/koi bhi OEM ho, sahi package names hi milein.
  /// Non-Android platforms ya koi bhi error par khaali list milegi --
  /// UI ko khud "no apps found" state dikhana chahiye.
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<Object?>>('getInstalledApps');
      if (result == null) return [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map((raw) => InstalledApp(
                packageName: raw['packageName'] as String? ?? '',
                label: raw['label'] as String? ?? '',
              ))
          .where((app) => app.packageName.isNotEmpty)
          .toList();
    } on PlatformException catch (e) {
      debugPrint('getInstalledApps failed: ${e.message}');
      return [];
    }
  }

  /// "Auto" tab ke liye -- kisi bhi installed app ka real icon leke,
  /// native side par consistent [shape] ("circle"/"squircle") + duotone
  /// [accentColorHex] (e.g. "#00FFF0") treatment apply karke wapas
  /// bhejta hai. Har app automatically apna unique-but-themed icon
  /// paata hai, koi manual PNG ke bagair.
  Future<Uint8List?> getThemedAppIcon({
    required String packageName,
    required String shape,
    required String accentColorHex,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Uint8List>('getThemedAppIcon', {
        'packageName': packageName,
        'shape': shape,
        'accentColor': accentColorHex,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('getThemedAppIcon failed for $packageName: ${e.message}');
      return null;
    }
  }

  // ---------------- CONTROL CENTER (Accessibility overlay) ----------------

  Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    final result =
        await _channel.invokeMethod<bool>('isAccessibilityEnabled');
    return result ?? false;
  }

  /// User ko seedha Settings > Accessibility screen par le jaata hai,
  /// jahan wo humari service ko manually ON karega. Ye bhi automatic
  /// nahi ho sakta -- Android khud user consent maangta hai.
  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openAccessibilitySettings');
  }
}