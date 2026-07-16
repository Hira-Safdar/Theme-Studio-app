import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_model.dart';
import 'native_bridge_service.dart';
import 'icon_pack_service.dart';

/// Ye ThemeController wahi gap fill karta hai jo humne pehle discuss kiya tha:
/// "Theme apply kyun nahi hota" -- kyunki alag alag features (wallpaper,
/// icon pack) ko sahi order me await ke sath, aur independent try-catch
/// ke sath combine karna zaroori hai. Agar ek step fail ho, baaki na ruken.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  String? activeThemeId;
  bool isApplying = false;
  final List<String> lastErrors = [];

  Future<void> applyTheme(ThemeModel theme) async {
    isApplying = true;
    lastErrors.clear();
    notifyListeners(); // UI ko turant pata chale "applying..." spinner dikhane ke liye

    // Step 1: Wallpaper
    try {
      final filePath = await IconPackService.instance.assetToFile(
        theme.wallpaperAssetPath,
        'wallpaper_${theme.id}',
      );
      final ok = await NativeBridgeService.instance
          .setWallpaper(filePath, target: 'both');
      if (!ok) lastErrors.add('Wallpaper could not be applied');
    } catch (e) {
      lastErrors.add('Wallpaper error: $e');
    }

    // Step 2: Icon pack ko "active pack" ke tor par save karo.
    // (Actual per-app icon shortcuts alag se, IconChangerScreen se, banaye
    // jaate hain -- kyunki har shortcut ke liye user confirmation chahiye,
    // isliye ek button dabate hi 50 shortcuts ek sath push nahi kar sakte.)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_icon_pack', theme.iconPackId);
      await prefs.setString('active_theme_id', theme.id);
    } catch (e) {
      lastErrors.add('Icon pack save error: $e');
    }

    activeThemeId = theme.id;
    isApplying = false;
    notifyListeners(); // UI turant refresh -- Home Screen preview turant update
  }

  Future<String?> getActiveIconPackId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_icon_pack');
  }
}
