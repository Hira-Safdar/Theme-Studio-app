import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../models/online_theme.dart';
import '../services/app_strings.dart';
import '../services/favorites_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/preset_theme_card.dart' show PresetCardStatus;
import 'theme_preview_screen.dart';
import 'online_theme_apply_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = ThemeController.instance;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
    FavoritesService.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    FavoritesService.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  PresetCardStatus _statusFor(ThemeModel theme) {
    final isActive = controller.activeThemeId == theme.id;
    if (!isActive) return PresetCardStatus.idle;
    if (controller.isApplying) return PresetCardStatus.applying;
    if (controller.lastErrors.isNotEmpty) return PresetCardStatus.partial;
    return PresetCardStatus.applied;
  }

  List<ThemeModel> _filteredPresetThemes() {
    var themes = List<ThemeModel>.from(presetThemes);
    if (_showFavoritesOnly) {
      themes = themes.where((t) => FavoritesService.instance.isFavorite(t.id)).toList();
    }
    return themes;
  }

  List<OnlineTheme> _filteredOnlineThemes() {
    var themes = List<OnlineTheme>.from(OnlineTheme.curated);
    if (_showFavoritesOnly) {
      themes = themes.where((t) => FavoritesService.instance.isFavorite(t.id)).toList();
    }
    return themes;
  }

  Future<void> _handlePresetTap(ThemeModel theme) async {
    await ThemePreviewScreen.show(context, theme);
  }

  void _handleOnlineTap(OnlineTheme theme) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnlineThemeApplyScreen(onlineTheme: theme)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = _filteredPresetThemes();
    final online = _filteredOnlineThemes();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_title')),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? AppTheme.error(context) : null,
            ),
            tooltip: tr('favorites_filter'),
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: _MixGrid(
        presetThemes: preset,
        onlineThemes: online,
        statusFor: _statusFor,
        onPresetTap: controller.isApplying ? null : _handlePresetTap,
        onOnlineTap: controller.isApplying ? null : _handleOnlineTap,
        onToggleFavorite: (id) => FavoritesService.instance.toggle(id),
        isFavorite: (id) => FavoritesService.instance.isFavorite(id),
      ),
    );
  }
}

class _MixGrid extends StatelessWidget {
  const _MixGrid({
    required this.presetThemes,
    required this.onlineThemes,
    required this.statusFor,
    required this.onPresetTap,
    required this.onOnlineTap,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final List<ThemeModel> presetThemes;
  final List<OnlineTheme> onlineThemes;
  final PresetCardStatus Function(ThemeModel) statusFor;
  final Future<void> Function(ThemeModel)? onPresetTap;
  final void Function(OnlineTheme)? onOnlineTap;
  final void Function(String id) onToggleFavorite;
  final bool Function(String id) isFavorite;

  @override
  Widget build(BuildContext context) {
    if (presetThemes.isEmpty && onlineThemes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            tr('favorites_empty'),
            style: AppTypography.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (presetThemes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Preset Themes',
              style: AppTypography.heading.copyWith(
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          ...presetThemes.map((theme) => _PresetMixCard(
            theme: theme,
            status: statusFor(theme),
            onTap: onPresetTap != null ? () => onPresetTap!(theme) : null,
            isFavorite: isFavorite(theme.id),
            onToggleFavorite: () => onToggleFavorite(theme.id),
          )),
          const SizedBox(height: AppSpacing.md),
        ],
        if (onlineThemes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Online Themes',
              style: AppTypography.heading.copyWith(
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          ...onlineThemes.map((theme) => _OnlineMixCard(
            theme: theme,
            onTap: onOnlineTap != null ? () => onOnlineTap!(theme) : null,
            isFavorite: isFavorite(theme.id),
            onToggleFavorite: () => onToggleFavorite(theme.id),
          )),
        ],
      ],
    );
  }
}

class _PresetMixCard extends StatelessWidget {
  const _PresetMixCard({
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

  @override
  Widget build(BuildContext context) {
    final accent = theme.accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: AppRadius.mdRadius,
          child: SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  theme.wallpaperAssetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: accent.withValues(alpha: 0.2),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
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
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: _previewIcon(theme.iconPackId),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                theme.name,
                                style: AppTypography.heading.copyWith(
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                titleCase(theme.iconPackId.replaceAll('_', ' ')),
                                style: AppTypography.bodySecondary.copyWith(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (status == PresetCardStatus.applied)
                          Icon(Icons.check_circle, color: AppTheme.success(context), size: 22)
                        else if (status == PresetCardStatus.applying)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        else
                          const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
                      ],
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

  Widget _previewIcon(String packId) {
    const keys = ['browser', 'calculator'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((key) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          width: 18,
          height: 18,
          child: Image.asset(
            'assets/icon_packs/$packId/$key.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.android, size: 12, color: Colors.white),
          ),
        ),
      )).toList(),
    );
  }
}

class _OnlineMixCard extends StatelessWidget {
  const _OnlineMixCard({
    required this.theme,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final OnlineTheme theme;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final accent = Color(theme.accentColorValue);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: AppRadius.mdRadius,
          child: SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.5),
                        accent.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: GestureDetector(
                    onTap: onToggleFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
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
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.language, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                theme.name,
                                style: AppTypography.heading.copyWith(
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Online',
                                style: AppTypography.bodySecondary.copyWith(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
                      ],
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
}
