import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../models/online_theme.dart';
import '../services/app_strings.dart';
import '../services/favorites_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/preset_theme_card.dart' show PresetCardStatus;
import '../widgets/theme_grid_tile.dart';
import 'theme_preview_screen.dart';
import 'online_theme_apply_screen.dart';

const List<String> _categories = ['nature', 'dark', 'minimal', 'abstract'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final controller = ThemeController.instance;
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length + 2, vsync: this);
    controller.addListener(_onChange);
    FavoritesService.instance.addListener(_onChange);
    FavoritesService.instance.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  String _categoryForTheme(ThemeModel theme) {
    for (final cat in _categories) {
      if (theme.id.startsWith('${cat}_') || theme.wallpaperAssetPath.contains('/$cat/')) {
        return cat;
      }
    }
    return _categories.first;
  }

  List<ThemeModel> _themesForCategory(String category) {
    return presetThemes.where((t) => _categoryForTheme(t) == category).toList();
  }

  List<ThemeModel> _filteredThemes(String category) {
    final themes = category == 'all'
        ? List<ThemeModel>.from(presetThemes)
        : _themesForCategory(category);
    if (_showFavoritesOnly) {
      return themes.where((t) => FavoritesService.instance.isFavorite(t.id)).toList();
    }
    return themes;
  }

  Future<void> _handleTap(ThemeModel theme) async {
    await ThemePreviewScreen.show(context, theme);
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: tr('all_categories')),
            ..._categories.map((c) => Tab(text: _titleCase(c))),
            Tab(text: tr('online_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PresetThemesGrid(
            themes: _filteredThemes('all'),
            statusFor: _statusFor,
            onTap: controller.isApplying ? null : _handleTap,
          ),
          ..._categories.map((cat) => _PresetThemesGrid(
            themes: _filteredThemes(cat),
            statusFor: _statusFor,
            onTap: controller.isApplying ? null : _handleTap,
          )),
          _OnlineThemesGrid(),
        ],
      ),
    );
  }
}

class _PresetThemesGrid extends StatelessWidget {
  const _PresetThemesGrid({
    required this.themes,
    required this.statusFor,
    required this.onTap,
  });

  final List<ThemeModel> themes;
  final PresetCardStatus Function(ThemeModel) statusFor;
  final Future<void> Function(ThemeModel)? onTap;

  @override
  Widget build(BuildContext context) {
    if (themes.isEmpty) {
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
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2 / 3,
      ),
      itemCount: themes.length,
      itemBuilder: (context, i) {
        final theme = themes[i];
        return ThemeGridTile(
          theme: theme,
          status: statusFor(theme),
          onTap: onTap != null ? () => onTap!(theme) : null,
          isFavorite: FavoritesService.instance.isFavorite(theme.id),
          onToggleFavorite: () => FavoritesService.instance.toggle(theme.id),
        );
      },
    );
  }
}

class _OnlineThemesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const themes = OnlineTheme.curated;
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2 / 3,
      ),
      itemCount: themes.length,
      itemBuilder: (context, i) {
        final theme = themes[i];
        final accent = Color(theme.accentColorValue);
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OnlineThemeApplyScreen(onlineTheme: theme),
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.lgRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.35),
                        accent.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
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
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
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
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.language, color: accent, size: 36),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        theme.name,
                        style: AppTypography.heading.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _titleCase(theme.category),
                        style: AppTypography.bodySecondary.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
