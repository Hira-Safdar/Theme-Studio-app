import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/online_icon_pack.dart';
import '../models/online_theme.dart';
import '../models/online_wallpaper.dart';
import '../services/app_strings.dart';
import '../services/download_service.dart';
import '../services/icon_pack_api.dart';
import '../services/icon_pack_service.dart';
import '../services/icon_matching_service.dart';
import '../services/native_bridge_service.dart';
import '../services/theme_controller.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../utils/ad_positions.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/wallpaper_preview.dart';

class _PackOption {
  final String id;
  final String name;
  final String description;
  final bool isBundled;
  final OnlineIconPack? onlinePack;
  const _PackOption({
    required this.id,
    required this.name,
    required this.description,
    required this.isBundled,
    this.onlinePack,
  });
}

class OnlineThemeApplyScreen extends StatefulWidget {
  const OnlineThemeApplyScreen({super.key, required this.onlineTheme});
  final OnlineTheme onlineTheme;

  @override
  State<OnlineThemeApplyScreen> createState() => _OnlineThemeApplyScreenState();
}

class _OnlineThemeApplyScreenState extends State<OnlineThemeApplyScreen> {
  List<OnlineWallpaper> _wallpapers = [];
  bool _loading = true;
  OnlineWallpaper? _selectedWallpaper;
  String _selectedIconPack = 'dark_mode';
  bool _applying = false;
  int _shortcutsTotal = 0;
  int _shortcutsDone = 0;
  List<_PackOption> _packOptions = [];
  bool _packsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadPacks();
  }

  Future<void> _fetch() async {
    try {
      final results = await DownloadService.instance.search(
        widget.onlineTheme.searchQuery,
        perPage: 20,
      );
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

  Future<void> _loadPacks() async {
    final options = <_PackOption>[
      const _PackOption(id: 'dark_mode', name: 'Dark Mode', description: 'Sleek dark-themed icons', isBundled: true),
      const _PackOption(id: 'cartoon', name: 'Cartoon', description: 'Playful cartoon-style icons', isBundled: true),
      const _PackOption(id: 'flat_colors', name: 'Flat Colors', description: 'Clean flat-color icons', isBundled: true),
    ];
    try {
      final onlinePacks = await IconPackApi.instance.fetch();
      for (final pack in onlinePacks) {
        if (pack.id == 'cartoon') continue;
        options.add(_PackOption(
          id: pack.id,
          name: pack.name,
          description: pack.description,
          isBundled: false,
          onlinePack: pack,
        ));
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _packOptions = options;
      _packsLoading = false;
    });
  }

  void _selectWallpaper(OnlineWallpaper wallpaper) {
    setState(() => _selectedWallpaper = wallpaper);
  }

  Future<void> _showPreviewAndApply() async {
    if (_selectedWallpaper == null) return;
    try {
      final target = await WallpaperPreviewScreen.show(
        context,
        wallpaperImageProvider(networkUrl: _selectedWallpaper!.url),
        downloadUrl: _selectedWallpaper!.url,
      );
      if (target == null || !mounted) return;

      final localPath = WallpaperPreviewScreen.lastDownloadedPath;
      if (localPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download wallpaper')),
        );
        return;
      }
      AdService.instance.showRewarded(placement: 'online_theme_apply', onComplete: () async {
        await _applyFromLocal(target, localPath);
      });
    } catch (_) {}
  }

  Future<void> _applyFromLocal(String target, String localPath) async {
    setState(() => _applying = true);

    try {
      debugPrint('===== _applyFromLocal START: target=$target, wallpaper=$localPath =====');
      final ok = await NativeBridgeService.instance.setWallpaper(localPath, target: target);
      debugPrint('ThemeApply: setWallpaper returned $ok');

      final installedApps = await NativeBridgeService.instance.getInstalledApps();
      debugPrint('ThemeApply: ${installedApps.length} installed apps');
      final selectedPack = _packOptions.where((p) => p.id == _selectedIconPack).firstOrNull;
      debugPrint('ThemeApply: selectedPack id=${selectedPack?.id} isBundled=${selectedPack?.isBundled} online=${selectedPack?.onlinePack?.name}');
      final errors = <String>[];
      if (!ok) errors.add('Wallpaper could not be applied');

      final shortcuts = <({String packageName, String appLabel, String iconFilePath})>[];

      if (selectedPack != null && selectedPack.isBundled) {
        debugPrint('ThemeApply: Using BUNDLED pack path');
        for (final app in installedApps) {
          final iconKey = IconMatchingService.instance.guessIconKey(app.packageName, app.label);
          if (iconKey != null) {
            try {
              final assetPath = IconPackService.instance.bundledAssetPath(selectedPack.id, iconKey);
              final filePath = await IconPackService.instance.assetToFile(assetPath, app.packageName);
              debugPrint('ThemeApply: [BUNDLED] ${app.label} -> key=$iconKey file=$filePath');
              shortcuts.add((packageName: app.packageName, appLabel: app.label, iconFilePath: filePath));
            } catch (e) {
              debugPrint('ThemeApply: [BUNDLED] ${app.label} FAILED: $e');
              errors.add('Icon prepare failed for ${app.label}: $e');
            }
          }
        }
      } else if (selectedPack != null && selectedPack.onlinePack != null) {
        final pack = selectedPack.onlinePack!;
        debugPrint('ThemeApply: Using ONLINE pack "${pack.name}" (${pack.iconUrls.length} icon URLs)');

        final pending = <Future<void>>[];
        final client = http.Client();
        final tempDir = await getTemporaryDirectory();
        const concurrency = 5;
        var active = 0;

        for (final app in installedApps) {
          final iconUrl = pack.iconUrls[app.packageName];
          if (iconUrl != null && iconUrl.isNotEmpty) {
            while (active >= concurrency) {
              await pending.removeAt(0);
              active--;
            }
            active++;
            pending.add(Future(() async {
              try {
                final response = await client.get(Uri.parse(iconUrl)).timeout(const Duration(seconds: 8));
                if (response.statusCode == 200) {
                  final file = File('${tempDir.path}/online_icon_${app.packageName.hashCode.abs()}.png');
                  await file.writeAsBytes(response.bodyBytes);
                  shortcuts.add((packageName: app.packageName, appLabel: app.label, iconFilePath: file.path));
                  debugPrint('ThemeApply: [ONLINE] ${app.label} (${app.packageName}) OK');
                } else {
                  errors.add('Icon download failed for ${app.label}');
                }
              } catch (e) {
                errors.add('Icon download error for ${app.label}: $e');
              }
            }));
          }
        }

        if (pending.isNotEmpty) {
          await Future.wait(pending);
          client.close();
        }
        debugPrint('ThemeApply: ${shortcuts.length} online shortcuts prepared from ${installedApps.length} apps');
      } else {
        debugPrint('ThemeApply: WARNING - no pack selected! selectedPack=$selectedPack');
      }

      _shortcutsTotal = shortcuts.length;
      debugPrint('ThemeApply: Total shortcuts to pin: ${shortcuts.length}');
      if (mounted) setState(() {});

      if (shortcuts.isNotEmpty) {
        debugPrint('ThemeApply: Calling batchCreateShortcuts with ${shortcuts.length} shortcuts...');
        final added = await NativeBridgeService.instance.batchCreateShortcuts(shortcuts: shortcuts);
        _shortcutsDone = added;
        debugPrint('ThemeApply: batchCreateShortcuts returned $added/${shortcuts.length}');
        if (added == 0 && shortcuts.isNotEmpty) {
          errors.add('No shortcuts could be created');
        }
        if (mounted) setState(() {});
      } else {
        debugPrint('ThemeApply: WARNING - NO shortcuts to pin!');
      }

      ThemeController.instance.setActiveTheme('online_${widget.onlineTheme.id}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            errors.isEmpty
                ? '${widget.onlineTheme.name} theme applied'
                : 'Applied with ${errors.length} step${errors.length == 1 ? '' : 's'} failed',
          ),
          action: errors.isEmpty
              ? null
              : SnackBarAction(
                  label: 'View details',
                  onPressed: () => _showErrorDetails(errors),
                ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _showErrorDetails(List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised(context),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: const Text('What failed', style: AppTypography.heading),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: errors.length,
            separatorBuilder: (_, __) => Divider(color: AppTheme.borderSubtle(context), height: AppSpacing.lg),
            itemBuilder: (context, i) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: AppTheme.error(context)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(errors[i], style: AppTypography.bodySecondary)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(widget.onlineTheme.name),
        leading: _applying
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: _selectedWallpaper == null ? _buildPickerView() : _buildPreviewView(),
    );
  }

  Widget _buildPickerView() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_wallpapers.isEmpty) {
      return Center(
        child: Text(tr('search_no_results'), style: AppTypography.bodySecondary),
      );
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Pick a wallpaper for your ${widget.onlineTheme.name} theme',
            style: AppTypography.bodySecondary,
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final adPosSet = randomAdPositions(_wallpapers.length, seed: 55).toSet();
              final totalSlots = _wallpapers.length + adPosSet.length;
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
                  if (adPosSet.any((ap) => ap + _adsBeforeCount(ap, adPosSet) == gridIndex)) {
                    return const NativeAdCard(placement: 'online_theme');
                  }
                  final contentIndex = gridIndex - adsBefore;
                  if (contentIndex < 0 || contentIndex >= _wallpapers.length) {
                    return const SizedBox.shrink();
                  }
                  final wallpaper = _wallpapers[contentIndex];
                  return GestureDetector(
                    onTap: () => _selectWallpaper(wallpaper),
                    child: ClipRRect(
                      borderRadius: AppRadius.mdRadius,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            wallpaper.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.surfaceRaised(context),
                              child: Icon(Icons.broken_image, color: AppTheme.textSecondary(context)),
                            ),
                          ),
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
                                style: AppTypography.bodySecondary.copyWith(color: Colors.white, fontSize: 10),
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

  Widget _buildPreviewView() {
    final selectedOption = _packOptions.where((p) => p.id == _selectedIconPack).firstOrNull;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _PhoneFrame(
              imageUrl: _selectedWallpaper!.thumbnailUrl,
              selectedPack: selectedOption,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
          child: Text('Choose Icon Pack', style: AppTypography.label.copyWith(color: AppTheme.textSecondary(context))),
        ),
        SizedBox(
          height: 120,
          child: _packsLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  scrollDirection: Axis.horizontal,
                  itemCount: _packOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final pack = _packOptions[i];
                    final isSelected = pack.id == _selectedIconPack;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconPack = pack.id),
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 90,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.accentPrimaryMuted(context) : AppTheme.surfaceRaised(context),
                          borderRadius: AppRadius.mdRadius,
                          border: Border.all(
                            color: isSelected ? AppTheme.accentPrimary(context) : AppTheme.borderSubtle(context),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: pack.isBundled
                                  ? _buildBundledIconPreview(pack.id)
                                  : _buildOnlineIconPreview(pack.onlinePack),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              pack.name,
                              style: AppTypography.label.copyWith(
                                fontSize: 10,
                                color: isSelected ? AppTheme.accentPrimary(context) : AppTheme.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.accentPrimary(context)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  selectedOption != null
                      ? '${selectedOption.name}: ${selectedOption.description}'
                      : 'Wallpaper + icon pack will be applied together.',
                  style: AppTypography.bodySecondary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _applying
                      ? null
                      : () => setState(() => _selectedWallpaper = null),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _applying ? null : _showPreviewAndApply,
                  child: _applying
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                _shortcutsTotal > 0
                                    ? '$_shortcutsDone/$_shortcutsTotal'
                                    : 'Applying…',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : const Text('Preview & Apply'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBundledIconPreview(String packId) {
    const keys = ['browser', 'camera', 'clock', 'settings'];
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: keys.map((key) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          IconPackService.instance.bundledAssetPath(packId, key),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.surface(context),
            child: Icon(Icons.android, size: 10, color: AppTheme.textSecondary(context)),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildOnlineIconPreview(OnlineIconPack? pack) {
    if (pack == null || pack.iconUrls.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.palette, size: 16, color: AppTheme.textSecondary(context)),
      );
    }
    final urls = pack.iconUrls.values.take(4).toList();
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: urls.map((url) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.surface(context),
            child: Icon(Icons.broken_image, size: 8, color: AppTheme.textSecondary(context)),
          ),
        ),
      )).toList(),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.imageUrl, required this.selectedPack});
  final String imageUrl;
  final _PackOption? selectedPack;

  @override
  Widget build(BuildContext context) {
    if (selectedPack != null && selectedPack!.isBundled) {
      const keys = ['browser', 'calculator', 'camera', 'clock'];
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppTheme.borderFocus(context), width: 6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceRaised(context)),
                  ),
                  _buildStatusBar(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: AppSpacing.xl,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: keys.map((key) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.mdRadius,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  IconPackService.instance.bundledAssetPath(selectedPack!.id, key),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.android,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (selectedPack != null && selectedPack!.onlinePack != null) {
      final urls = selectedPack!.onlinePack!.iconUrls.values.take(4).toList();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: AspectRatio(
            aspectRatio: 9 / 19.5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppTheme.borderFocus(context), width: 6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceRaised(context)),
                  ),
                  _buildStatusBar(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: AppSpacing.xl,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: urls.map((url) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.mdRadius,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.android,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: AspectRatio(
          aspectRatio: 9 / 19.5,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.borderFocus(context), width: 6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(imageUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceRaised(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: 0.55,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9:41',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.signal_cellular_alt, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Icon(Icons.wifi, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Icon(Icons.battery_full, color: Colors.white, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
