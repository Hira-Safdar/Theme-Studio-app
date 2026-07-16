import 'dart:io';
import 'package:flutter/foundation.dart'; // debugPrint ke liye
import 'package:flutter/services.dart';

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
