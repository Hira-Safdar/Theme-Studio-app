import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:image_picker/image_picker.dart';
import '../data/online_wallpapers.dart';
import '../models/online_wallpaper.dart';
import '../services/app_strings.dart';
import '../services/download_service.dart';
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
const List<String> _onlineCategories = ['nature', 'abstract', 'dark', 'minimal'];

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
    _tabController = TabController(length: _categories.length + 1, vsync: this);
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

  Future<void> _previewThenApplyFromOnline(OnlineWallpaper wallpaper) async {
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(assetPath: wallpaper.thumbnailUrl),
    );
    if (target == null || !mounted) return;

    setState(() => _applying = true);
    try {
      final localPath = await DownloadService.instance.download(wallpaper.url);
      if (localPath == null) {
        _showResult(false);
        return;
      }
      final ok = await NativeBridgeService.instance.setWallpaper(localPath, target: target);
      _showResult(ok);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('wallpaper_title')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            ..._categories.map((c) => Tab(text: _titleCase(c))),
            Tab(text: tr('online_tab')),
          ],
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
              children: [
                ..._categories.map((category) {
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
                }),
                // Online wallpapers tab
                _OnlineWallpaperGrid(
                  onApply: _previewThenApplyFromOnline,
                ),
              ],
            ),
    );
  }
}

/// Grid of downloadable wallpapers from the internet. Shows category
/// chips at the top to filter, and a 2-column grid of thumbnails below.
String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class _OnlineWallpaperGrid extends StatefulWidget {
  const _OnlineWallpaperGrid({required this.onApply});
  final Future<void> Function(OnlineWallpaper) onApply;

  @override
  State<_OnlineWallpaperGrid> createState() => _OnlineWallpaperGridState();
}

class _OnlineWallpaperGridState extends State<_OnlineWallpaperGrid> {
  String _selectedCategory = 'all';

  List<OnlineWallpaper> get _filtered {
    if (_selectedCategory == 'all') return curatedOnlineWallpapers;
    return curatedOnlineWallpapers.where((w) => w.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _CategoryChip(
                label: 'All',
                isSelected: _selectedCategory == 'all',
                onTap: () => setState(() => _selectedCategory = 'all'),
              ),
              ..._onlineCategories.map((c) => _CategoryChip(
                label: _titleCase(c),
                isSelected: _selectedCategory == c,
                onTap: () => setState(() => _selectedCategory = c),
              )),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 2 / 3,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final wallpaper = _filtered[i];
              return GestureDetector(
                onTap: () => widget.onApply(wallpaper),
                child: ClipRRect(
                  borderRadius: AppRadius.mdRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        wallpaper.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.bgSurfaceRaised,
                          child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
                        ),
                      ),
                      // Author credit at bottom
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                            ),
                          ),
                          child: Text(
                            wallpaper.author,
                            style: AppTypography.bodySecondary.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentPrimaryMuted : AppColors.bgSurfaceRaised,
            borderRadius: AppRadius.smRadius,
            border: Border.all(
              color: isSelected ? AppColors.accentPrimary : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}