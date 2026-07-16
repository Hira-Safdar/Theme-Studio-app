import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import '../services/native_bridge_service.dart';
import '../services/icon_pack_service.dart';

/// Category folder names -- yeh humari assets/wallpapers/<category>/
/// folder structure se match karti hain. Naya category add karna ho to:
/// 1. assets/wallpapers/<naya_naam>/ folder banayein
/// 2. pubspec.yaml me "assets:" list me path add karein
/// 3. neeche _categories list me naam add karein
const List<String> _categories = ['nature', 'abstract', 'dark', 'minimal'];

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});
  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// category -> list of asset paths, e.g. "nature" -> ["assets/wallpapers/nature/1.jpg", ...]
  Map<String, List<String>> _wallpapersByCategory = {};
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadAssets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);
    final allPaths = manifestMap.keys.toList();

    final Map<String, List<String>> grouped = {};
    for (final category in _categories) {
      final prefix = 'assets/wallpapers/$category/';
      final matches = allPaths.where((p) => p.startsWith(prefix)).toList();
      // Naam ke hisaab se sort taake 1.jpg, 2.jpg, 3.jpg order mein aayein.
      matches.sort();
      grouped[category] = matches;
    }

    if (mounted) {
      setState(() {
        _wallpapersByCategory = grouped;
        _loading = false;
      });
    }
  }

  Future<void> _applyFromAsset(String assetPath) async {
    setState(() => _applying = true);
    try {
      final tempPath = await IconPackService.instance.assetToFile(
        assetPath,
        assetPath.hashCode.toString(),
      );
      final ok = await NativeBridgeService.instance.setWallpaper(tempPath);
      _showResult(ok);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _applyFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _applying = true);
    try {
      final ok = await NativeBridgeService.instance.setWallpaper(picked.path);
      _showResult(ok);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showResult(bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Wallpaper applied ✅' : 'Failed ❌')),
    );
  }

  String _titleCase(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpapers'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _categories.map((c) => Tab(text: _titleCase(c))).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _applying ? null : _applyFromGallery,
            tooltip: 'Choose your own wallpaper from gallery',
          ),
        ],
      ),
      body: _loading || _applying
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                final wallpapers = _wallpapersByCategory[category] ?? [];
                if (wallpapers.isEmpty) {
                  return Center(
                    child: Text('No images found in assets/wallpapers/$category/'),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: wallpapers.length,
                  itemBuilder: (context, i) {
                    final path = wallpapers[i];
                    return GestureDetector(
                      onTap: () => _applyFromAsset(path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(path, fit: BoxFit.cover),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }
}
