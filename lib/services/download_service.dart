import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Handles downloading wallpaper images from URLs to local cache.
/// Returns local file paths that can be used with setWallpaper().
class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

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
