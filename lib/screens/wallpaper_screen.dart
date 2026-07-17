import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:image_picker/image_picker.dart';
import '../services/native_bridge_service.dart';
import '../services/icon_pack_service.dart';
import '../theme/app_theme.dart';
import '../widgets/wallpaper_preview.dart';

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
    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allPaths = assetManifest.listAssets();

      final Map<String, List<String>> grouped = {};
      for (final category in _categories) {
        final prefix = 'assets/wallpapers/$category/';
        final matches = allPaths.where((p) => p.startsWith(prefix)).toList();
        matches.sort();
        grouped[category] = matches;
      }

      if (mounted) {
        setState(() {
          _wallpapersByCategory = grouped;
          _loading = false;
        });
      }
    } catch (_) {
      // Asset manifest couldn't be read (e.g. missing assets, or a test
      // environment without a built asset bundle). Fall back to empty
      // categories — the grid already shows a "No images found" message
      // per category in that case, instead of crashing the screen.
      if (mounted) {
        setState(() {
          _wallpapersByCategory = {for (final c in _categories) c: <String>[]};
          _loading = false;
        });
      }
    }
  }

  /// Opens the phone-frame preview first; only calls the native setter if
  /// the user confirms Apply from that screen. §3.3.
  Future<void> _previewThenApplyFromAsset(String assetPath) async {
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(assetPath: assetPath),
    );
    if (target == null || !mounted) return; // user ne cancel kiya

    setState(() => _applying = true);
    try {
      final tempPath = await IconPackService.instance.assetToFile(
        assetPath,
        assetPath.hashCode.toString(),
      );
      final ok = await NativeBridgeService.instance
          .setWallpaper(tempPath, target: target);
      _showResult(ok);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _previewThenApplyFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(filePath: picked.path),
    );
    if (target == null || !mounted) return; // user ne cancel kiya

    setState(() => _applying = true);
    try {
      final ok = await NativeBridgeService.instance
          .setWallpaper(picked.path, target: target);
      _showResult(ok);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showResult(bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Wallpaper applied' : 'Couldn\'t apply — tap to retry')),
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
            onPressed: _applying ? null : _previewThenApplyFromGallery,
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
                    child: Text(
                      'No images found in assets/wallpapers/$category/',
                      style: AppTypography.bodySecondary,
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2 / 3,
                  ),
                  itemCount: wallpapers.length,
                  itemBuilder: (context, i) {
                    final path = wallpapers[i];
                    return GestureDetector(
                      onTap: () => _previewThenApplyFromAsset(path),
                      child: ClipRRect(
                        borderRadius: AppRadius.mdRadius,
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