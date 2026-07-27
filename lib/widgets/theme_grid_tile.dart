// lib/widgets/theme_grid_tile.dart
//
// Home screen's theme tile, restyled to match the Wallpaper screen's
// visual language: a real image thumbnail you tap (not a plain text row).
// Shows the theme's actual wallpaper as the tile background, with the
// name + accent dot legible over a bottom gradient, and a small status
// badge (applying/applied/partial) in the corner -- same status concept
// as the old PresetThemeCard, just presented as a grid tile.

import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/icon_pack_service.dart';
import '../theme/app_theme.dart';
import 'preset_theme_card.dart' show PresetCardStatus;

/// Sirf 2 sample icons -- tile chhota hai (2-column grid), zyada icons
/// cramped/messy lagenge. ThemePreviewScreen (poore-screen wala preview)
/// mein 4 dikhte hain, wahan jagah zyada hai.
const List<String> _tilePreviewIconKeys = ['browser', 'calculator'];

class ThemeGridTile extends StatelessWidget {
  const ThemeGridTile({
    super.key,
    required this.theme,
    required this.status,
    required this.onTap,
  });

  final ThemeModel theme;
  final PresetCardStatus status;
  final VoidCallback? onTap;

  Color get _accentColor => theme.accentColor;

  @override
  Widget build(BuildContext context) {
    final subtitle = 'Icon pack: ${theme.iconPackId}';
    return Semantics(
      label: status == PresetCardStatus.partial
          ? '${theme.name}. Applied with some steps failed.'
          : '${theme.name}. $subtitle.',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: AppRadius.lgRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                theme.wallpaperAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.bgSurfaceRaised),
              ),
              // Bottom gradient -- keeps the name legible over any wallpaper,
              // same trick used in the phone-frame preview's status bar.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          theme.name,
                          style: AppTypography.body.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (status != PresetCardStatus.idle)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: _StatusBadge(status: status),
                ),
              // Is theme ke icon pack ke 2 real sample icons -- taake grid
              // mein sirf wallpaper nahi, icon-style bhi ek nazar mein
              // pata chale.
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: _tilePreviewIconKeys
                      .map(
                        (key) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppRadius.smRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              IconPackService.instance.bundledAssetPath(theme.iconPackId, key),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.android,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final PresetCardStatus status;

  @override
  Widget build(BuildContext context) {
    late final Widget child;
    switch (status) {
      case PresetCardStatus.idle:
        child = const SizedBox.shrink();
        break;
      case PresetCardStatus.applying:
        child = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        );
        break;
      case PresetCardStatus.applied:
        child = const Icon(Icons.check_circle, color: AppColors.success, size: 18);
        break;
      case PresetCardStatus.partial:
        // Partial-failure must stay visually distinct from a plain
        // success check (§6 accessibility rule from the original spec).
        child = const Icon(Icons.error, color: AppColors.error, size: 18);
        break;
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}