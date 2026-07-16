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
}

/// App ke andar available preset themes. Naye themes yahan add karte jaayein.
/// NOTE: wallpaperAssetPath ab category folder ke andar wali specific
/// image ka path hona chahiye (e.g. assets/wallpapers/nature/1.png) --
/// aapki numbered images ke hisaab se exact filename yahan update kar dein.
const List<ThemeModel> presetThemes = [
  ThemeModel(
    id: 'nature_cartoon',
    name: 'Nature + Cartoon',
    wallpaperAssetPath: 'assets/wallpapers/nature/1.png',
    iconPackId: 'cartoon',
    accentColorHex: '#4CAF50',
  ),
  ThemeModel(
    id: 'dark_darkmode',
    name: 'Dark + Dark Mode Icons',
    wallpaperAssetPath: 'assets/wallpapers/dark/1.png',
    iconPackId: 'dark_mode',
    accentColorHex: '#00FFF0',
  ),
  ThemeModel(
    id: 'minimal_flat',
    name: 'Minimal + Flat Colors',
    wallpaperAssetPath: 'assets/wallpapers/minimal/1.png',
    iconPackId: 'flat_colors',
    accentColorHex: '#2196F3',
  ),
];