import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_strings.dart';
import '../services/locale_controller.dart';
import '../services/theme_mode_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_row.dart';

const String _privacyPolicyUrl = 'https://example.com/theme-studio-privacy';
const String _playStorePackageId = 'com.example.theme_studio';
const String _feedbackEmail = 'hirasafdar04@gmail.com';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _languages = {
    'en': 'English',
    'ur': 'اردو',
    'es': 'Espanol',
    'fr': 'Francais',
  };

  Future<void> _openLanguagePicker() async {
    final currentCode = LocaleController.instance.languageCode;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceRaised(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languages.entries.map((entry) {
            final isSelected = entry.key == currentCode;
            return ListTile(
              title: Text(entry.value, style: AppTypography.body),
              trailing: isSelected
                  ? Icon(Icons.check, color: AppTheme.accentPrimary(context))
                  : null,
              onTap: () => Navigator.of(context).pop(entry.key),
            );
          }).toList(),
        ),
      ),
    );
    if (selected != null) {
      await LocaleController.instance.setLanguage(selected);
    }
  }

  Future<void> _openLink(Uri uri) async {
    if (uri.host == 'example.com') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This link will be available once the app is published')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open that link")),
      );
    }
  }

  void _openExplainer(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/settings/explainer/${title.hashCode}'),
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Text(body, style: AppTypography.body),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.lg,
        ),
        children: [
          SettingsSectionHeader(label: tr('settings_section_general')),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.language,
                label: tr('settings_language'),
                trailingText: _languages[LocaleController.instance.languageCode],
                onTap: _openLanguagePicker,
              ),
              ListenableBuilder(
                listenable: ThemeModeController.instance,
                builder: (context, _) => SettingsRow(
                  icon: ThemeModeController.instance.isDark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  label: tr('settings_dark_mode'),
                  toggleValue: ThemeModeController.instance.isDark,
                  onToggleChanged: (v) => ThemeModeController.instance.setDark(v),
                ),
              ),
            ],
          ),
          SettingsSectionHeader(label: tr('settings_section_help')),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.apps_outlined,
                label: tr('settings_how_icons'),
                onTap: () => _openExplainer(
                  tr('settings_how_icons'),
                  "Android doesn't let apps replace another app's icon directly. "
                      'When you tap Apply on the Icon changer screen, Theme studio '
                      'creates a new Home Screen shortcut with the icon you picked. '
                      "Android will show a confirmation dialog before it's added - "
                      "that's a one-time system check, not something the app controls.",
                ),
              ),
              SettingsRow(
                icon: Icons.widgets_outlined,
                label: tr('settings_how_widgets'),
                onTap: () => _openExplainer(
                  tr('settings_how_widgets'),
                  'Home Screen widgets are drawn entirely by Android, not by this app. '
                      'Tapping "Pin to Home Screen" sends a request to your launcher, '
                      "which shows its own confirmation before adding the widget. "
                      'Once pinned, the widget updates itself in the background.',
                ),
              ),

              SettingsRow(
                icon: Icons.mail_outline,
                label: tr('settings_send_feedback'),
                onTap: () => _openLink(
                  Uri(
                    scheme: 'mailto',
                    path: _feedbackEmail,
                    query: 'subject=${Uri.encodeComponent('Theme Studio feedback')}',
                  ),
                ),
              ),
            ],
          ),
          SettingsSectionHeader(label: tr('settings_section_about')),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: tr('settings_privacy'),
                onTap: () => _openLink(Uri.parse(_privacyPolicyUrl)),
              ),
              SettingsRow(
                icon: Icons.star_outline,
                label: tr('settings_rate'),
                onTap: () => _openLink(
                  Uri.parse('https://play.google.com/store/apps/details?id=$_playStorePackageId'),
                ),
              ),
              SettingsRow(
                icon: Icons.info_outline,
                label: tr('settings_version'),
                trailingText: '1.0.0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
