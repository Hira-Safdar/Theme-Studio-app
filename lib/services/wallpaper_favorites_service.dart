import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperFavoritesService extends ChangeNotifier {
  WallpaperFavoritesService._();
  static final WallpaperFavoritesService instance = WallpaperFavoritesService._();

  static const _favKey = 'favorite_wallpaper_ids';
  static const _myKey = 'my_wallpaper_paths';

  final Set<String> _favIds = {};
  final List<String> _myPaths = [];
  bool _loaded = false;

  Set<String> get favIds => Set.unmodifiable(_favIds);
  List<String> get myPaths => List.unmodifiable(_myPaths);

  bool isFavorite(String id) => _favIds.contains(id);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favKey);
    if (raw != null) _favIds.addAll(raw);
    final myRaw = prefs.getStringList(_myKey);
    if (myRaw != null) _myPaths.addAll(myRaw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    if (_favIds.contains(id)) {
      _favIds.remove(id);
    } else {
      _favIds.add(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, _favIds.toList());
  }

  Future<void> addMyWallpaper(String path) async {
    if (_myPaths.contains(path)) return;
    _myPaths.insert(0, path);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_myKey, _myPaths.toList());
  }

  Future<void> removeMyWallpaper(String path) async {
    _myPaths.remove(path);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_myKey, _myPaths.toList());
  }
}
