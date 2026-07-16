import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/theme_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Theme Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Select a theme — wallpaper and icon pack will be applied together.',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ...presetThemes.map((theme) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Color(int.parse(theme.accentColorHex.replaceFirst('#', '0xFF'))),
                  ),
                  title: Text(theme.name),
                  subtitle: Text('Icon pack: ${theme.iconPackId}'),
                  trailing: controller.isApplying && controller.activeThemeId == theme.id
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : (controller.activeThemeId == theme.id
                          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                          : const Icon(Icons.chevron_right)),
                  onTap: controller.isApplying
                      ? null
                      : () async {
                          await controller.applyTheme(theme);
                          final errors = controller.lastErrors;
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errors.isEmpty
                                  ? '${theme.name} applied successfully ✅'
                                  : 'Some steps failed: ${errors.join(', ')}'),
                            ),
                          );
                        },
                ),
              )),
        ],
      ),
    );
  }
}
