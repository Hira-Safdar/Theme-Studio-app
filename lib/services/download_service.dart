import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/online_wallpaper.dart';

/// Fetches wallpapers from Unsplash (primary) and Pexels (fallback) APIs,
/// then downloads them locally. Unsplash has 4M+ high-quality photos with
/// excellent portrait/wallpaper support.
class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  static const _defaultUnsplashKey = 'YqMRKaMXbg9N60sPY1Mr8oVV-Hqt85u_XeWe8Si4uQI';
  static const _defaultPexelsKey = 'AQCX98AIYY6zUXau91LwigRCUXqiTnWeEIldXHKc5R9kkuzo62KIVoZH';

  String? _unsplashKey;
  String? _pexelsKey;
  bool get hasApiKey => hasUnsplashKey || hasPexelsKey;
  bool get hasUnsplashKey => _unsplashKey != null && _unsplashKey!.isNotEmpty;
  bool get hasPexelsKey => _pexelsKey != null && _pexelsKey!.isNotEmpty;

  final _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  Future<void> load() async {
    _unsplashKey = _defaultUnsplashKey;
    _pexelsKey = _defaultPexelsKey;
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<List<OnlineWallpaper>> search(String query, {int perPage = 20}) async {
    await ready;

    if (hasUnsplashKey) {
      final results = await _searchUnsplash(query, perPage: perPage);
      if (results.isNotEmpty) return results;
    }

    if (hasPexelsKey) {
      final results = await _searchPexels(query, perPage: perPage);
      if (results.isNotEmpty) return results;
    }

    return [];
  }

  Future<List<OnlineWallpaper>> _searchUnsplash(String query, {int perPage = 20}) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&per_page=$perPage&orientation=portrait&content_filter=low',
            ),
            headers: {
              'Authorization': 'Client-ID $_unsplashKey',
              'Accept-Version': 'v1',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];

      return results.map((photo) {
        final urls = photo['urls'] as Map<String, dynamic>;
        final user = photo['user'] as Map<String, dynamic>? ?? {};
        final name = user['name'] as String? ?? 'Unknown';
        final id = photo['id'] as String? ?? '';
        return OnlineWallpaper(
          id: 'unsplash_$id',
          url: urls['regular'] as String? ?? urls['full'] as String? ?? '',
          thumbnailUrl: urls['small'] as String? ?? urls['thumb'] as String? ?? '',
          category: query,
          author: name,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<OnlineWallpaper>> _searchPexels(String query, {int perPage = 20}) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.pexels.com/v1/search?query=${Uri.encodeComponent(query)}&per_page=$perPage&orientation=portrait',
            ),
            headers: {'Authorization': _pexelsKey!},
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

  Future<String?> download(String url, {void Function(double progress)? onProgress}) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) return null;

      final totalBytes = response.contentLength;
      final bytes = <int>[];
      int received = 0;
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (onProgress != null && totalBytes != null && totalBytes > 0) {
          onProgress(received / totalBytes);
        }
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'wallpaper_${url.hashCode.abs()}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (onProgress != null) onProgress(1.0);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
