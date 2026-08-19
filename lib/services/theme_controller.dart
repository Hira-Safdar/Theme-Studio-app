import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_model.dart';
import 'native_bridge_service.dart';
import 'icon_pack_service.dart';
import 'icon_matching_service.dart';

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

  /// Batch-apply progress -- "3 of 12 shortcuts requested" jaisa UI dikhane
  /// ke liye. isApplying == true hone par hi meaningful hai.
  int shortcutsTotal = 0;
  int shortcutsDone = 0;

  Future<void> applyTheme(ThemeModel theme) async {
    isApplying = true;
    lastErrors.clear();
    shortcutsTotal = 0;
    shortcutsDone = 0;
    notifyListeners(); // UI ko turant pata chale "applying..." spinner dikhane ke liye

    // Step 1: Wallpaper
    try {
      final filePath = await IconPackService.instance.assetToFile(
        theme.wallpaperAssetPath,
        'wallpaper_${theme.id}',
      );
      final ok = await NativeBridgeService.instance
          .setWallpaper(filePath, target: 'both');
      if (!ok) {
        lastErrors.add('Wallpaper could not be applied');
        debugPrint('ThemeController: Wallpaper step failed');
      } else {
        debugPrint('ThemeController: Wallpaper step succeeded');
      }
    } catch (e) {
      lastErrors.add('Wallpaper error: $e');
      debugPrint('ThemeController: Wallpaper error: $e');
    }

    // Step 2: Icon pack ko "active pack" ke tor par save karo.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_icon_pack', theme.iconPackId);
      await prefs.setString('active_theme_id', theme.id);
      debugPrint('ThemeController: Icon pack save succeeded');
    } catch (e) {
      lastErrors.add('Icon pack save error: $e');
      debugPrint('ThemeController: Icon pack save error: $e');
    }

    // Step 3: Installed apps ko bundled icon se match karke shortcuts request karo.
    try {
      final installedApps = await NativeBridgeService.instance.getInstalledApps();
      final matches = <({String packageName, String label, String iconKey})>[];
      for (final app in installedApps) {
        if (!app.isSystemApp) continue;

        final iconKey = IconMatchingService.instance.guessIconKey(app.packageName, app.label);
        if (iconKey != null) {
          matches.add((packageName: app.packageName, label: app.label, iconKey: iconKey));
        }
      }

      shortcutsTotal = matches.length;
      debugPrint('ThemeController: Found ${matches.length} matching apps');
      notifyListeners(); // taake UI turant "0 of N" dikha sake

      for (final match in matches) {
        try {
          final ok = await IconMatchingService.instance.applyBundledIconShortcut(
            packId: theme.iconPackId,
            packageName: match.packageName,
            appLabel: match.label,
            iconKey: match.iconKey,
          );
          if (!ok) {
            lastErrors.add('Icon shortcut failed for ${match.label}');
            debugPrint('ThemeController: Shortcut failed for ${match.label}');
          } else {
            debugPrint('ThemeController: Shortcut succeeded for ${match.label}');
          }
        } catch (e) {
          lastErrors.add('Icon shortcut error for ${match.label}: $e');
          debugPrint('ThemeController: Shortcut error for ${match.label}: $e');
        }
        shortcutsDone++;
        notifyListeners(); // progress UI ko live update karta hai
      }
      debugPrint('ThemeController: Icon shortcuts step completed with ${lastErrors.where((e) => e.contains('shortcut')).length} errors');
    } catch (e) {
      lastErrors.add('Could not read installed apps: $e');
      debugPrint('ThemeController: Could not read installed apps: $e');
    }

    debugPrint('ThemeController: Total errors: ${lastErrors.length}');
    for (final error in lastErrors) {
      debugPrint('ThemeController: Error - $error');
    }

    activeThemeId = theme.id;
    isApplying = false;
    notifyListeners(); // UI turant refresh -- Home Screen preview turant update
  }

  Future<String?> getActiveIconPackId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_icon_pack');
  }

  void setActiveTheme(String? id) {
    activeThemeId = id;
    notifyListeners();
  }
}