// lib/widgets/preset_theme_card.dart
//
// Shared component, used only on Home (§3.2 / §2 of the build prompt).
// Renders: mood swatch + name + icon-pack subtitle + status.
// Status is one of: idle (chevron) / applying (spinner) / applied (check) /
// partial-result (split ✅/❌ — never collapsed to one icon, §5 + §6).

import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../theme/app_theme.dart';

enum PresetCardStatus { idle, applying, applied, partial }

class PresetThemeCard extends StatelessWidget {
  const PresetThemeCard({
    super.key,
    required this.theme,
    required this.status,
    required this.onTap,
    this.errorSummary,
  });

  final ThemeModel theme;
  final PresetCardStatus status;
  final VoidCallback? onTap;

  /// Short text describing what failed, shown only when [status] is
  /// [PresetCardStatus.partial]. e.g. "Wallpaper couldn't be applied".
  final String? errorSummary;

  Color _swatchColor(BuildContext context) {
    try {
      return Color(int.parse(theme.accentColorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.accentPrimary(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = 'Icon pack: ${theme.iconPackId}';

    return Semantics(

      // Partial-failure state must announce both outcomes to screen
      // readers, not just the visible icon (§6).
      label: status == PresetCardStatus.partial
          ? '${theme.name}. Applied with some steps failed: ${errorSummary ?? 'see details'}.'
          : '${theme.name}. $subtitle.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: AppTheme.level1(context, radius: AppRadius.lgRadius),
            child: Row(
              children: [
                _MoodSwatch(color: _swatchColor(context)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.name, style: AppTypography.heading),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypography.bodySecondary),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusIndicator(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodSwatch extends StatelessWidget {
  const _MoodSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});
  final PresetCardStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case PresetCardStatus.idle:
        return Icon(Icons.chevron_right, color: AppTheme.textSecondary(context));

      case PresetCardStatus.applying:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );

      case PresetCardStatus.applied:
        return Icon(Icons.check_circle, color: AppTheme.success(context));

      case PresetCardStatus.partial:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppTheme.success(context), size: 18),
            const SizedBox(width: 4),
            Icon(Icons.error, color: AppTheme.error(context), size: 18),
          ],
        );
    }
  }
}