import 'package:flutter/material.dart';

/// Ek "Theme" sirf ek data bundle hai. Isme khud koi logic nahi hoti,
/// ye bas batata hai ke apply karne par kaunsa wallpaper aur kaunsa
/// icon pack use hoga. Actual apply karne ka kaam ThemeController karta hai
/// (services/theme_controller.dart).
class ThemeModel {
  final String id;
  final String name;
  final String wallpaperAssetPath; // assets/wallpapers/xyz.png
  final String iconPackId; // e.g. "cartoon", "flat_colors", "dark_mode" (assets/icon_packs/<id>/)
  final String accentColorHex; // e.g. "#00FFF0"

  const ThemeModel({
    required this.id,
    required this.name,
    required this.wallpaperAssetPath,
    required this.iconPackId,
    required this.accentColorHex,
  });

  /// [accentColorHex] ("#RRGGBB") ko Flutter [Color] mein badalta hai.
  /// Parse fail hone par fallback accentPrimary return karta hai.
  Color get accentColor {
    try {
      return Color(int.parse(accentColorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF00FFF0); // AppColors.accentPrimary
    }
  }
}

/// App ke andar available preset themes. Naye themes yahan add karte jaayein.
/// NOTE: wallpaperAssetPath ab category folder ke andar wali specific
/// image ka path hona chahiye (e.g. assets/wallpapers/nature/1.png) --
/// aapki numbered images ke hisaab se exact filename yahan update kar dein.
///
/// Ye poora "matrix" hai: har wallpaper category (nature/dark/minimal/
/// abstract) x har icon pack (cartoon/flat_colors/dark_mode) ka ek combo --
/// taake jitne bhi wallpapers maujood hain unka poora fayda uthaya jaaye,
/// har combo ek distinct naam + accent color ke saath.
const List<ThemeModel> presetThemes = [
  // ---------------- Nature ----------------
  ThemeModel(
    id: 'nature_cartoon',
    name: 'Forest Cartoon',
    wallpaperAssetPath: 'assets/wallpapers/nature/1.png',
    iconPackId: 'cartoon',
    accentColorHex: '#4CAF50',
  ),
  ThemeModel(
    id: 'nature_flat',
    name: 'Woodland Teal',
    wallpaperAssetPath: 'assets/wallpapers/nature/7.png',
    iconPackId: 'flat_colors',
    accentColorHex: '#009688',
  ),
  ThemeModel(
    id: 'nature_darkmode',
    name: 'Evergreen Dusk',
    wallpaperAssetPath: 'assets/wallpapers/nature/14.png',
    iconPackId: 'dark_mode',
    accentColorHex: '#2E7D32',
  ),

  // ---------------- Dark ----------------
  ThemeModel(
    id: 'dark_darkmode',
    name: 'Cyan Nights',
    wallpaperAssetPath: 'assets/wallpapers/dark/1.png',
    iconPackId: 'dark_mode',
    accentColorHex: '#00FFF0',
  ),
  ThemeModel(
    id: 'dark_cartoon',
    name: 'Midnight Pop',
    wallpaperAssetPath: 'assets/wallpapers/dark/6.png',
    iconPackId: 'cartoon',
    accentColorHex: '#FFC107',
  ),
  ThemeModel(
    id: 'dark_flat',
    name: 'Twilight Violet',
    wallpaperAssetPath: 'assets/wallpapers/dark/9.png',
    iconPackId: 'flat_colors',
    accentColorHex: '#7C4DFF',
  ),

  // ---------------- Minimal ----------------
  ThemeModel(
    id: 'minimal_flat',
    name: 'Clean Blue',
    wallpaperAssetPath: 'assets/wallpapers/minimal/1.png',
    iconPackId: 'flat_colors',
    accentColorHex: '#2196F3',
  ),
  ThemeModel(
    id: 'minimal_darkmode',
    name: 'Slate Minimal',
    wallpaperAssetPath: 'assets/wallpapers/minimal/9.png',
    iconPackId: 'dark_mode',
    accentColorHex: '#607D8B',
  ),
  ThemeModel(
    id: 'minimal_cartoon',
    name: 'Pastel Pop',
    wallpaperAssetPath: 'assets/wallpapers/minimal/5.png',
    iconPackId: 'cartoon',
    accentColorHex: '#FF4081',
  ),

  // ---------------- Abstract ----------------
  ThemeModel(
    id: 'abstract_cartoon',
    name: 'Abstract Sunset',
    wallpaperAssetPath: 'assets/wallpapers/abstract/1.png',
    iconPackId: 'cartoon',
    accentColorHex: '#FF7043',
  ),
  ThemeModel(
    id: 'abstract_flat',
    name: 'Indigo Waves',
    wallpaperAssetPath: 'assets/wallpapers/abstract/6.png',
    iconPackId: 'flat_colors',
    accentColorHex: '#3F51B5',
  ),
  ThemeModel(
    id: 'abstract_darkmode',
    name: 'Neon Abstract',
    wallpaperAssetPath: 'assets/wallpapers/abstract/10.png',
    iconPackId: 'dark_mode',
    accentColorHex: '#E91E63',
  ),
];