import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/app_strings.dart';
import '../services/favorites_service.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/preset_theme_card.dart' show PresetCardStatus;
import '../widgets/theme_grid_tile.dart';
import 'theme_preview_screen.dart';

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
    FavoritesService.instance.load();
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

  Future<void> _handleTap(ThemeModel theme) async {
    // Seedha apply nahi karte -- pehle Wallpaper screen jaisa ek preview
    // dikhate hain (wallpaper + is pack ke real sample icons), user Apply
    // tap kare tabhi ThemeController.applyTheme() chalta hai (ye khud
    // ThemePreviewScreen ke andar hota hai).
    await ThemePreviewScreen.show(context, theme);
    // controller already ChangeNotifier hai (listener already lagi hai),
    // isliye card ka status apne aap refresh ho jaayega -- yahan kuch
    // extra karne ki zarurat nahi.
  }

  @override
  Widget build(BuildContext context) {
    final displayedThemes = _showFavoritesOnly
        ? presetThemes.where((t) => FavoritesService.instance.isFavorite(t.id)).toList()
        : presetThemes;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_title')),
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? AppColors.error : null,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
              0,
            ),
            child: Text(
              _showFavoritesOnly
                  ? tr('favorites_empty')
                  : tr('home_instruction'),
              style: AppTypography.bodySecondary,
            ),
          ),
          Expanded(
            child: displayedThemes.isEmpty
                ? Center(
                    child: Text(
                      tr('favorites_empty'),
                      style: AppTypography.bodySecondary,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 2 / 3,
                    ),
                    itemCount: displayedThemes.length,
                    itemBuilder: (context, i) {
                      final theme = displayedThemes[i];
                      return ThemeGridTile(
                        theme: theme,
                        status: _statusFor(theme),
                        onTap: controller.isApplying ? null : () => _handleTap(theme),
                        isFavorite: FavoritesService.instance.isFavorite(theme.id),
                        onToggleFavorite: () => FavoritesService.instance.toggle(theme.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}