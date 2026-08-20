import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/icon_pack_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';

const List<String> _previewIconKeys = ['browser', 'calculator', 'camera', 'clock'];

class ThemePreviewScreen extends StatefulWidget {
  const ThemePreviewScreen({super.key, required this.theme});

  final ThemeModel theme;

  static Future<bool?> show(BuildContext context, ThemeModel theme) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ThemePreviewScreen(theme: theme)),
    );
  }

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  final _controller = ThemeController.instance;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  Color get _accentColor => widget.theme.accentColor;

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await _controller.applyTheme(widget.theme);
    } catch (_) {}
    if (!mounted) return;

    final errors = List<String>.from(_controller.lastErrors);
    final themeName = widget.theme.name;
    setState(() => _applying = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          errors.isEmpty
              ? '$themeName applied'
              : 'Applied with ${errors.length} step${errors.length == 1 ? '' : 's'} failed',
        ),
        action: errors.isEmpty
            ? null
            : SnackBarAction(
                label: 'View details',
                onPressed: () => _showErrorDetails(context, themeName, errors),
              ),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showErrorDetails(BuildContext context, String themeName, List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceRaised(context),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
        title: Text('$themeName — what failed', style: AppTypography.heading),
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
        title: Text(widget.theme.name),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close preview',
          onPressed: _applying ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _ThemePhoneFrame(theme: widget.theme, accentColor: _accentColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Icon pack: ${widget.theme.iconPackId}',
                      style: AppTypography.bodySecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.sm,
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
                      'Applying will also request Home Screen shortcuts for every '
                      'matching app. Android confirms each shortcut separately, so '
                      'several confirmations may appear one after another.',
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
                      onPressed: _applying ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applying ? null : _apply,
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
                                    _controller.shortcutsTotal > 0
                                        ? '${_controller.shortcutsDone}/${_controller.shortcutsTotal}'
                                        : 'Applying…',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : const Text('Apply theme'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePhoneFrame extends StatelessWidget {
  const _ThemePhoneFrame({required this.theme, required this.accentColor});
  final ThemeModel theme;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
                  Image.asset(
                    theme.wallpaperAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: AppTheme.surfaceRaised(context)),
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
                                IconPackService.instance
                                    .bundledAssetPath(theme.iconPackId, key),
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
      ),
    );
  }
}