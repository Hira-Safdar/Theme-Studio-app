import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/online_wallpaper.dart';

/// Fetches wallpapers from the Pexels API and downloads them locally.
/// Pexels offers free wallpaper images. API key is user-provided (free
/// tier: 200 requests/hour). Key is stored in SharedPreferences.
class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  static const _prefsKey = 'pexels_api_key';
  static const _defaultApiKey = 'AQCX98AIYY6zUXau91LwigRCUXqiTnWeEIldXHKc5R9kkuzo62KIVoZH';

  String? _apiKey;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Completes once [load] has finished reading SharedPreferences.
  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Loads saved API key from SharedPreferences on app start.
  /// Falls back to built-in default key if none saved.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefsKey) ?? _defaultApiKey;
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, key);
    }
  }

  /// Searches Pexels for [query] wallpapers, returns up to [perPage] results.
  /// Returns empty list on failure or if no API key is set.
  Future<List<OnlineWallpaper>> search(String query, {int perPage = 20}) async {
    await ready;
    if (_apiKey == null || _apiKey!.isEmpty) return [];
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.pexels.com/v1/search?query=${Uri.encodeComponent(query)}&per_page=$perPage&orientation=portrait',
            ),
            headers: {'Authorization': _apiKey!},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final photos = data['photos'] as List<dynamic>? ?? [];

      return photos.map((photo) {
        final src = photo['src'] as Map<String, dynamic>;
        final photographer = photo['photographer'] as String? ?? 'Unknown';
        final id = (photo['id'] as num).toInt();
        return OnlineWallpaper(
          id: 'pexels_$id',
          url: src['large2x'] as String? ?? src['large'] as String? ?? '',
          thumbnailUrl: src['medium'] as String? ?? src['small'] as String? ?? '',
          category: query,
          author: photographer,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Downloads the image at [url] to the app's cache directory.
  /// Returns the local file path on success, null on failure.
  Future<String?> download(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final fileName = 'wallpaper_${url.hashCode.abs()}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
