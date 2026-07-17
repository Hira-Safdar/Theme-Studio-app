import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_row.dart';

// TODO: replace with your real privacy policy URL once you have one hosted.
const String _privacyPolicyUrl = 'https://example.com/theme-studio-privacy';

// TODO: replace with your real Play Store applicationId once the app is
// published under its real package name (currently still the Flutter
// template default, com.example.theme_studio, which has no real listing).
const String _playStorePackageId = 'com.example.theme_studio';

const String _feedbackEmail = 'hirasafdar04@gmail.com';

/// Settings — everything that isn't one of the four core tools. §3.7.
/// Reached via the gear icon on Home's app bar (not a 6th nav tab, §4).
/// No coin/currency balance, no PRO badge, no ad banners, no upsell —
/// nothing in the product brief calls for a monetization layer.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _languageCode = 'en';

  static const _languages = {
    'en': 'English',
    'ur': 'اردو',
    'es': 'Español',
    'fr': 'Français',
  };

  Future<void> _openLanguagePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgSurfaceRaised,
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
            final isSelected = entry.key == _languageCode;
            return ListTile(
              title: Text(entry.value, style: AppTypography.body),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.accentPrimary)
                  : null,
              onTap: () => Navigator.of(context).pop(entry.key),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _languageCode = selected);
    }
  }

  Future<void> _openLink(Uri uri) async {
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.lg,
        ),
        children: [
          const SettingsSectionHeader(label: 'General'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.language,
                label: 'Language',
                trailingText: _languages[_languageCode],
                onTap: _openLanguagePicker,
              ),
              SettingsRow(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                toggleValue: _notificationsEnabled,
                onToggleChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
            ],
          ),
          const SettingsSectionHeader(label: 'Help'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.apps_outlined,
                label: 'How icon shortcuts work',
                onTap: () => _openExplainer(
                  'How icon shortcuts work',
                  'Android doesn\'t let apps replace another app\'s icon directly. '
                      'When you tap Apply on the Icon changer screen, Theme studio '
                      'creates a new Home Screen shortcut with the icon you picked. '
                      'Android will show a confirmation dialog before it\'s added — '
                      'that\'s a one-time system check, not something the app controls.',
                ),
              ),
              SettingsRow(
                icon: Icons.widgets_outlined,
                label: 'How widgets work',
                onTap: () => _openExplainer(
                  'How widgets work',
                  'Home Screen widgets are drawn entirely by Android, not by this app. '
                      'Tapping "Pin to Home Screen" sends a request to your launcher, '
                      'which shows its own confirmation before adding the widget. '
                      'Once pinned, the widget updates itself in the background.',
                ),
              ),
              SettingsRow(
                icon: Icons.tune,
                label: 'How Control Center works',
                onTap: () => _openExplainer(
                  'How Control Center works',
                  'Control Center is an overlay drawn using Android\'s Accessibility '
                      'Service. That service needs to be turned on once in Android '
                      'Settings — Android requires this to be a manual, explicit step. '
                      'Once it\'s on, swipe down from the top of the screen to open '
                      'the overlay from anywhere.',
                ),
              ),
              SettingsRow(
                icon: Icons.mail_outline,
                label: 'Send feedback',
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
          const SettingsSectionHeader(label: 'About'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy policy',
                onTap: () => _openLink(Uri.parse(_privacyPolicyUrl)),
              ),
              SettingsRow(
                icon: Icons.star_outline,
                label: 'Rate the app',
                onTap: () => _openLink(
                  Uri.parse('https://play.google.com/store/apps/details?id=$_playStorePackageId'),
                ),
              ),
              const SettingsRow(
                icon: Icons.info_outline,
                label: 'Version',
                trailingText: '1.0.0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}