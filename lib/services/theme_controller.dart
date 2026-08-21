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

    // Step 3: Installed apps ko bundled icon se match karke batch mein shortcuts add karo.
    try {
      final installedApps = await NativeBridgeService.instance.getInstalledApps();
      debugPrint('ThemeController: getInstalledApps returned ${installedApps.length} apps');
      final shortcuts = <({String packageName, String appLabel, String iconFilePath})>[];

      final pending = <Future<void>>[];
      const concurrency = 5;
      var active = 0;

      for (final app in installedApps) {
        final iconKey = IconMatchingService.instance.guessIconKey(app.packageName, app.label);
        if (iconKey != null) {
          while (active >= concurrency) {
            await pending.removeAt(0);
            active--;
          }
          active++;
          pending.add(Future(() async {
            try {
              final assetPath = IconPackService.instance.bundledAssetPath(theme.iconPackId, iconKey);
              final filePath = await IconPackService.instance.assetToFile(assetPath, app.packageName);
              debugPrint('ThemeController: Prepared shortcut for ${app.label} (${app.packageName}) key=$iconKey file=$filePath');
              shortcuts.add((packageName: app.packageName, appLabel: app.label, iconFilePath: filePath));
            } catch (e) {
              debugPrint('ThemeController: Icon prepare FAILED for ${app.label}: $e');
              lastErrors.add('Icon prepare failed for ${app.label}: $e');
            }
          }));
        }
      }

      if (pending.isNotEmpty) await Future.wait(pending);

      shortcutsTotal = shortcuts.length;
      debugPrint('ThemeController: ${shortcuts.length} shortcuts ready to pin (theme.iconPackId=${theme.iconPackId})');
      notifyListeners();

      if (shortcuts.isEmpty) {
        debugPrint('ThemeController: WARNING - no shortcuts to pin! guessIconKey returned null for all ${installedApps.length} apps');
      } else {
        final added = await NativeBridgeService.instance.batchCreateShortcuts(shortcuts: shortcuts);
        shortcutsDone = added;
        debugPrint('ThemeController: batchCreateShortcuts returned $added/${shortcuts.length}');
        if (added == 0) {
          lastErrors.add('No shortcuts could be created');
        }
        notifyListeners();
      }
    } catch (e) {
      lastErrors.add('Could not read installed apps: $e');
      debugPrint('ThemeController: ERROR in shortcuts step: $e');
    }

    debugPrint('ThemeController: Total errors: ${lastErrors.length}');
    for (final error in lastErrors) {
      debugPrint('ThemeController: Error - $error');
    }

    activeThemeId = theme.id;
    isApplying = false;
    notifyListeners(); // UI turant refresh -- Home Screen preview turant update
  }

  void setActiveTheme(String? id) {
    activeThemeId = id;
    notifyListeners();
  }
}