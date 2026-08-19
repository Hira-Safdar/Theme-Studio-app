import 'package:flutter/material.dart';
import '../models/online_theme.dart';
import '../models/online_wallpaper.dart';
import '../services/app_strings.dart';
import '../services/download_service.dart';
import '../services/icon_pack_service.dart';
import '../services/icon_matching_service.dart';
import '../services/native_bridge_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pack_selector.dart';
import '../widgets/wallpaper_preview.dart';

const List<String> _iconPackOptions = ['cartoon', 'flat_colors', 'dark_mode'];

String _iconPackLabel(String id) {
  switch (id) {
    case 'flat_colors':
      return 'Flat Colors';
    case 'dark_mode':
      return 'Dark Mode';
    default:
      return 'Cartoon';
  }
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

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final results = await DownloadService.instance.search(
      widget.onlineTheme.searchQuery,
      perPage: 20,
    );
    if (!mounted) return;
    setState(() {
      _wallpapers = results;
      _loading = false;
    });
  }

  void _selectWallpaper(OnlineWallpaper wallpaper) {
    setState(() => _selectedWallpaper = wallpaper);
  }

  Future<void> _showPreviewAndApply() async {
    if (_selectedWallpaper == null) return;
    final target = await WallpaperPreviewScreen.show(
      context,
      wallpaperImageProvider(networkUrl: _selectedWallpaper!.url),
    );
    if (target == null || !mounted) return;
    await _apply(target);
  }

  Future<void> _apply(String target) async {
    setState(() => _applying = true);

    try {
      final localPath = await DownloadService.instance.download(_selectedWallpaper!.url);
      if (localPath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download wallpaper')),
        );
        setState(() => _applying = false);
        return;
      }

      final ok = await NativeBridgeService.instance.setWallpaper(localPath, target: target);

      final installedApps = await NativeBridgeService.instance.getInstalledApps();
      final matches = <({String packageName, String label, String iconKey})>[];
      for (final app in installedApps) {
        if (!app.isSystemApp) continue;
        final iconKey = IconMatchingService.instance.guessIconKey(app.packageName, app.label);
        if (iconKey != null) {
          matches.add((packageName: app.packageName, label: app.label, iconKey: iconKey));
        }
      }
      _shortcutsTotal = matches.length;
      if (mounted) setState(() {});

      final errors = <String>[];
      if (!ok) errors.add('Wallpaper could not be applied');

      for (final match in matches) {
        try {
          final shortcutOk = await IconMatchingService.instance.applyBundledIconShortcut(
            packId: _selectedIconPack,
            packageName: match.packageName,
            appLabel: match.label,
            iconKey: match.iconKey,
          );
          if (!shortcutOk) errors.add('Icon shortcut failed for ${match.label}');
        } catch (e) {
          errors.add('Icon shortcut error for ${match.label}: $e');
        }
        _shortcutsDone++;
        if (mounted) setState(() {});
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
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 2 / 3,
            ),
            itemCount: _wallpapers.length,
            itemBuilder: (context, i) {
              final wallpaper = _wallpapers[i];
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
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _PhoneFrame(
              imageUrl: _selectedWallpaper!.thumbnailUrl,
              iconPackId: _selectedIconPack,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: PackSelector(
            options: _iconPackOptions,
            selected: _selectedIconPack,
            onChanged: (id) => setState(() => _selectedIconPack = id),
            labelBuilder: _iconPackLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            0,
            AppSpacing.screenPadding,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.accentPrimary(context)),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Wallpaper + icon pack will be applied together. '
                  'Android confirms each shortcut separately.',
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
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.imageUrl, required this.iconPackId});
  final String imageUrl;
  final String iconPackId;

  static const _previewIconKeys = ['browser', 'calculator', 'camera', 'clock'];

  @override
  Widget build(BuildContext context) {
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
                const Positioned(
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
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.xl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _previewIconKeys
                        .map(
                          (key) => Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppRadius.mdRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              IconPackService.instance.bundledAssetPath(iconPackId, key),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.android,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
