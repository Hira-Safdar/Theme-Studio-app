import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/icon_pack_service.dart';
import '../theme/app_theme.dart';
import 'preset_theme_card.dart' show PresetCardStatus;

const List<String> _tilePreviewIconKeys = ['browser', 'calculator'];

class ThemeGridTile extends StatelessWidget {
  const ThemeGridTile({
    super.key,
    required this.theme,
    required this.status,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final ThemeModel theme;
  final PresetCardStatus status;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

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
                errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceRaised(context)),
              ),
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
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: GestureDetector(
                  onTap: onToggleFavorite,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isFavorite ? AppTheme.error(context) : Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.xxxl,
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
        child = Icon(Icons.check_circle, color: AppTheme.success(context), size: 18);
        break;
      case PresetCardStatus.partial:
        child = Icon(Icons.error, color: AppTheme.error(context), size: 18);
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