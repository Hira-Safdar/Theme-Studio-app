import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/preset_theme_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
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
    await controller.applyTheme(theme);
    final errors = controller.lastErrors;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errors.isEmpty
              ? '${theme.name} applied'
              : 'Applied with some steps failed — tap to retry',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text(
            'Select a theme — wallpaper and icon pack will be applied together.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          ...presetThemes.map(
            (theme) => PresetThemeCard(
              theme: theme,
              status: _statusFor(theme),
              errorSummary:
                  controller.activeThemeId == theme.id && controller.lastErrors.isNotEmpty
                      ? controller.lastErrors.join(', ')
                      : null,
              onTap: controller.isApplying ? null : () => _handleTap(theme),
            ),
          ),
        ],
      ),
    );
  }
}