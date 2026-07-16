import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Icon ka source do tarah se aa sakta hai:
/// 1. bundled  -> humari app ke assets/icon_packs/<packId>/<appKey>.png se
/// 2. custom   -> user ne apni gallery se is specific app ke liye icon choose kiya
enum IconSource { bundled, custom }

class ResolvedIcon {
  final IconSource source;
  final String path; // bundled ho to asset path, custom ho to file path
  ResolvedIcon(this.source, this.path);
}

class IconPackService {
  IconPackService._();
  static final IconPackService instance = IconPackService._();

  final ImagePicker _picker = ImagePicker();

  /// Bundled icon packs ka naming convention: appKey = app ka simple keyword
  /// jaise "whatsapp", "facebook", "instagram" -- yehi convention
  /// IconPackCatalog.assetForAppName() (real_launcher) me bhi use hui thi.
  String bundledAssetPath(String packId, String appKey) {
    return 'assets/icon_packs/$packId/$appKey.png';
  }

  /// User ne kisi app ke liye gallery se custom icon choose kiya hai ya nahi,
  /// wo SharedPreferences me file-path ke tor par save/retrieve hota hai.
  Future<String?> getCustomIconPath(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_icon_$packageName');
  }

  /// Gallery se image pick karke app ke apne permanent storage me copy karta hai
  /// (temporary gallery cache pe depend nahi karte), phir path save karta hai.
  Future<String?> pickAndSaveCustomIcon(String packageName) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/custom_icons/$packageName.png';
    final destFile = File(destPath);
    await destFile.parent.create(recursive: true);
    await File(picked.path).copy(destPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_icon_$packageName', destPath);

    return destPath;
  }

  Future<void> removeCustomIcon(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('custom_icon_$packageName');
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      await prefs.remove('custom_icon_$packageName');
    }
  }

  /// Ye function decide karta hai ke final icon kahan se aayega:
  /// pehle custom (agar user ne apna icon set kiya hua hai), warna bundled pack.
  Future<ResolvedIcon> resolveIcon({
    required String packageName,
    required String appKey,
    required String activePackId,
  }) async {
    final customPath = await getCustomIconPath(packageName);
    if (customPath != null && await File(customPath).exists()) {
      return ResolvedIcon(IconSource.custom, customPath);
    }
    return ResolvedIcon(
      IconSource.bundled,
      bundledAssetPath(activePackId, appKey),
    );
  }

  /// Bundled (asset) icon ko ek real file me convert karta hai, kyunki
  /// Kotlin ki ShortcutManager ko ek file-system path chahiye hota hai,
  /// Flutter asset bundle path nahi chal sakta seedha.
  Future<String> assetToFile(String assetPath, String cacheKey) async {
    final byteData = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/icon_cache_$cacheKey.png');
    await file.writeAsBytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
    return file.path;
  }
}
