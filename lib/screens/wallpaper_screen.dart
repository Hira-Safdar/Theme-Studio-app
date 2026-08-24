import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:image_picker/image_picker.dart';
import '../models/online_wallpaper.dart';
import '../services/app_strings.dart';
import '../services/download_service.dart';
import '../services/wallpaper_favorites_service.dart';
import '../utils/ad_positions.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/wallpaper_preview.dart';

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
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length + 2, vsync: this);
    _tabController.index = 1;
    _loadAssets();
    WallpaperFavoritesService.instance.load();
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
      if (mounted) {
        setState(() {
          _wallpapersByCategory = {
            for (final c in _categories) c: <String>[]
          };
          _loading = false;
        });
      }
    }
  }

  Future<void> _previewThenApplyFromAsset(String assetPath) async {
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(assetPath: assetPath),
      wallpaperId: 'asset_$assetPath',
    );
    if (target == null || !mounted) return;
    setState(() {});
    _showResult(true);
  }

  Future<void> _previewThenApplyFromMy(String filePath) async {
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(filePath: filePath),
      wallpaperId: 'my_$filePath',
    );
    if (target == null || !mounted) return;
    setState(() {});
    _showResult(true);
  }

  Future<void> _importFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    await WallpaperFavoritesService.instance.addMyWallpaper(picked.path);
    if (!mounted) return;
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(filePath: picked.path),
      wallpaperId: 'my_${picked.path}',
    );
    if (target == null || !mounted) return;
    setState(() {});
    _showResult(true);
  }

  void _showResult(bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? tr('wallpaper_applied') : tr('wallpaper_failed'),
        ),
      ),
    );
  }

  Future<void> _previewThenApplyFromOnline(
    OnlineWallpaper wallpaper,
  ) async {
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(networkUrl: wallpaper.thumbnailUrl),
      downloadUrl: wallpaper.url,
      wallpaperId: wallpaper.url,
    );
    if (!mounted) return;
    setState(() {});
    _showResult(target != null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WallpaperFavoritesService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('wallpaper_title')),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(text: tr('my_tab')),
                Tab(text: tr('online_tab')),
                ..._categories.map((c) => Tab(text: titleCase(c))),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showFavoritesOnly
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _showFavoritesOnly ? AppTheme.error(context) : null,
                ),
                tooltip: tr('favorites_filter'),
                onPressed: () => setState(
                  () => _showFavoritesOnly = !_showFavoritesOnly,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _MyWallpapersGrid(
                            onApply: _previewThenApplyFromMy,
                            onImport: _importFromGallery,
                          ),
                          _OnlineWallpaperGrid(
                            onApply: _previewThenApplyFromOnline,
                          ),
                          ..._categories.map((category) {
                            final wallpapers =
                                _wallpapersByCategory[category] ?? [];
                            if (wallpapers.isEmpty) {
                              return Center(
                                child: Text(
                                  tr('no_wallpapers_found'),
                                  style: AppTypography.bodySecondary,
                                ),
                              );
                            }
                            return _AssetWallpaperGrid(
                              wallpapers: wallpapers,
                              onApply: _previewThenApplyFromAsset,
                              showFavoritesOnly: _showFavoritesOnly,
                            );
                          }),
                        ],
                      ),
              ),
              const Center(child: BannerAdWidget(placement: 'wallpaper')),
            ],
          ),
        );
      },
    );
  }
}

class _AssetWallpaperGrid extends StatelessWidget {
  const _AssetWallpaperGrid({
    required this.wallpapers,
    required this.onApply,
    required this.showFavoritesOnly,
  });
  final List<String> wallpapers;
  final Future<void> Function(String) onApply;
  final bool showFavoritesOnly;

  @override
  Widget build(BuildContext context) {
    final displayed = showFavoritesOnly
        ? wallpapers.where((path) {
            final id = 'asset_$path';
            return WallpaperFavoritesService.instance.isFavorite(id);
          }).toList()
        : wallpapers;

    if (displayed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_border,
                size: 48,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                tr('favorites_empty'),
                style: AppTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final adPosSet =
        randomAdPositions(displayed.length, seed: displayed.length).toSet();
    final totalSlots = displayed.length + adPosSet.length;

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2 / 3,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, gridIndex) {
        var adsBefore = 0;
        for (final ap in adPosSet) {
          final slotIndex = ap + _adsBeforeCount(ap, adPosSet);
          if (slotIndex <= gridIndex) {
            adsBefore++;
          } else {
            break;
          }
        }
        if (adPosSet.any(
          (ap) => ap + _adsBeforeCount(ap, adPosSet) == gridIndex,
        )) {
          return const NativeAdCard(placement: 'wallpaper_categories');
        }
        final contentIndex = gridIndex - adsBefore;
        if (contentIndex < 0 || contentIndex >= displayed.length) {
          return const SizedBox.shrink();
        }
        final path = displayed[contentIndex];
        final id = 'asset_$path';
        final isFav = WallpaperFavoritesService.instance.isFavorite(id);
        final isApplied =
            WallpaperPreviewScreen.lastAppliedId == 'asset_$path';
        return GestureDetector(
          onTap: () => onApply(path),
          child: ClipRRect(
            borderRadius: AppRadius.mdRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(path, fit: BoxFit.cover),
                if (isApplied)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: () => WallpaperFavoritesService.instance
                        .toggleFavorite(id),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFav ? AppTheme.error(context) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _adsBeforeCount(int adPos, Set<int> allAdPositions) {
    var count = 0;
    for (final ap in allAdPositions) {
      if (ap < adPos) count++;
    }
    return count;
  }
}

class _MyWallpapersGrid extends StatelessWidget {
  const _MyWallpapersGrid({required this.onApply, required this.onImport});
  final Future<void> Function(String) onApply;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final paths = WallpaperFavoritesService.instance.myPaths;
    if (paths.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 56,
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr('my_wallpapers_empty'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                label: Text(tr('import_gallery')),
              ),
            ],
          ),
        ),
      );
    }
    final adPosSet = randomAdPositions(paths.length, seed: 77).toSet();
    final totalSlots = paths.length + adPosSet.length;

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2 / 3,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, gridIndex) {
        var adsBefore = 0;
        for (final ap in adPosSet) {
          if (ap + _adsBeforeCount(ap, adPosSet) <= gridIndex) {
            adsBefore++;
          } else {
            break;
          }
        }
        if (adPosSet.any(
          (ap) => ap + _adsBeforeCount(ap, adPosSet) == gridIndex,
        )) {
          return const NativeAdCard(placement: 'wallpaper_my');
        }
        final contentIndex = gridIndex - adsBefore;
        if (contentIndex < 0 || contentIndex >= paths.length) {
          return const SizedBox.shrink();
        }
        final path = paths[contentIndex];
        final isApplied =
            WallpaperPreviewScreen.lastAppliedId == 'my_$path';
        return GestureDetector(
          onTap: () => onApply(path),
          child: ClipRRect(
            borderRadius: AppRadius.mdRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(path), fit: BoxFit.cover),
                if (isApplied)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: () => WallpaperFavoritesService.instance
                        .removeMyWallpaper(path),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _adsBeforeCount(int adPos, Set<int> allAdPositions) {
    var count = 0;
    for (final ap in allAdPositions) {
      if (ap < adPos) count++;
    }
    return count;
  }
}

class _OnlineWallpaperGrid extends StatefulWidget {
  const _OnlineWallpaperGrid({required this.onApply});
  final Future<void> Function(OnlineWallpaper) onApply;

  @override
  State<_OnlineWallpaperGrid> createState() => _OnlineWallpaperGridState();
}

class _OnlineWallpaperGridState extends State<_OnlineWallpaperGrid> {
  final _searchController = TextEditingController();
  List<OnlineWallpaper> _wallpapers = [];
  bool _loading = false;
  bool _hasSearched = false;
  bool _initialFetchDone = false;

  @override
  void initState() {
    super.initState();
    _doInitialFetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialFetchDone &&
        !_loading &&
        _wallpapers.isEmpty &&
        DownloadService.instance.hasApiKey) {
      _doInitialFetch();
    }
  }

  Future<void> _doInitialFetch() async {
    _initialFetchDone = true;
    await _fetchWallpapers('wallpaper');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallpapers(String query) async {
    if (query.trim().isEmpty) return;
    if (!DownloadService.instance.hasApiKey) return;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final results = await DownloadService.instance.search(query);
      if (!mounted) return;
      setState(() {
        _wallpapers = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchController,
            onSubmitted: _fetchWallpapers,
            decoration: InputDecoration(
              hintText: tr('search_wallpapers_hint'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smRadius,
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.surfaceRaised(context),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _wallpapers.isEmpty
                  ? Center(
                      child: Text(
                        _hasSearched ? tr('search_no_results') : '',
                        style: AppTypography.bodySecondary,
                      ),
                    )
                  : ListenableBuilder(
                      listenable: WallpaperFavoritesService.instance,
                      builder: (context, _) {
                        final adPosSet = randomAdPositions(
                          _wallpapers.length,
                          seed: 99,
                        ).toSet();
                        final totalSlots =
                            _wallpapers.length + adPosSet.length;
                        return GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 2 / 3,
                          ),
                          itemCount: totalSlots,
                          itemBuilder: (context, gridIndex) {
                            var adsBefore = 0;
                            for (final ap in adPosSet) {
                              if (ap + _adsBeforeCount(ap, adPosSet) <=
                                  gridIndex) {
                                adsBefore++;
                              } else {
                                break;
                              }
                            }
                            if (adPosSet.any(
                              (ap) =>
                                  ap +
                                      _adsBeforeCount(ap, adPosSet) ==
                                  gridIndex,
                            )) {
                              return const NativeAdCard(
                                placement: 'wallpaper_online',
                              );
                            }
                            final contentIndex = gridIndex - adsBefore;
                            if (contentIndex < 0 ||
                                contentIndex >= _wallpapers.length) {
                              return const SizedBox.shrink();
                            }
                            final wallpaper = _wallpapers[contentIndex];
                            final isFav = WallpaperFavoritesService.instance
                                .isFavorite(wallpaper.id);
                            final isApplied =
                                WallpaperPreviewScreen.lastAppliedId ==
                                    wallpaper.url;
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
                                        color: AppTheme.surfaceRaised(
                                          context,
                                        ),
                                        child: Icon(
                                          Icons.broken_image,
                                          color: AppTheme.textSecondary(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isApplied)
                                      Positioned(
                                        top: AppSpacing.sm,
                                        right: AppSpacing.sm,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                              alpha: 0.85,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: AppSpacing.sm,
                                      left: AppSpacing.sm,
                                      child: GestureDetector(
                                        onTap: () =>
                                            WallpaperFavoritesService.instance
                                                .toggleFavorite(
                                                  wallpaper.id,
                                                ),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isFav
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 18,
                                            color: isFav
                                                ? AppTheme.error(context)
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: 0.7,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          wallpaper.author,
                                          style: AppTypography
                                              .bodySecondary
                                              .copyWith(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  int _adsBeforeCount(int adPos, Set<int> allAdPositions) {
    var count = 0;
    for (final ap in allAdPositions) {
      if (ap < adPos) count++;
    }
    return count;
  }
}
