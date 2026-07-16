import 'package:flutter/material.dart';
import '../services/icon_pack_service.dart';
import '../services/native_bridge_service.dart';

/// Ek app entry: package name, label, aur icon-pack lookup ke liye keyword.
class AppEntry {
  final String packageName;
  final String label;
  final String iconKey; // e.g. "whatsapp" -> assets/icon_packs/<pack>/whatsapp.png
  const AppEntry(this.packageName, this.label, this.iconKey);
}

/// Demo list -- production me ye PackageManager se installed apps ki
/// actual list honi chahiye (native side se query karke Flutter ko bhejein).
const List<AppEntry> demoApps = [
  AppEntry('com.whatsapp', 'WhatsApp', 'whatsapp'),
  AppEntry('com.facebook.katana', 'Facebook', 'facebook'),
  AppEntry('com.instagram.android', 'Instagram', 'instagram'),
  AppEntry('com.google.android.youtube', 'YouTube', 'youtube'),
];

/// Available icon packs -- matches assets/icon_packs/<id>/ folder structure.
const List<String> availableIconPacks = ['cartoon', 'flat_colors', 'dark_mode'];

String _packDisplayName(String id) {
  switch (id) {
    case 'cartoon':
      return 'Cartoon';
    case 'flat_colors':
      return 'Flat Colors';
    case 'dark_mode':
      return 'Dark Mode';
    default:
      return id;
  }
}

class IconChangerScreen extends StatefulWidget {
  const IconChangerScreen({super.key});
  @override
  State<IconChangerScreen> createState() => _IconChangerScreenState();
}

class _IconChangerScreenState extends State<IconChangerScreen> {
  String activePackId = availableIconPacks.first;
  bool _busy = false;

  Future<void> _applyBundledOrCustomIcon(AppEntry app) async {
    setState(() => _busy = true);
    try {
      final resolved = await IconPackService.instance.resolveIcon(
        packageName: app.packageName,
        appKey: app.iconKey,
        activePackId: activePackId,
      );

      final String filePath;
      if (resolved.source == IconSource.custom) {
        filePath = resolved.path; // pehle se hi ek real file hai
      } else {
        filePath = await IconPackService.instance
            .assetToFile(resolved.path, app.packageName);
      }

      final ok = await NativeBridgeService.instance.createIconShortcut(
        packageName: app.packageName,
        appLabel: app.label,
        iconFilePath: filePath,
      );

      _showResult(ok, extra: 'A confirmation dialog will appear on the Home Screen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCustomIcon(AppEntry app) async {
    setState(() => _busy = true);
    try {
      final path = await IconPackService.instance.pickAndSaveCustomIcon(app.packageName);
      if (path == null) return; // user cancelled
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Custom icon saved for ${app.label}. Now tap "Apply".')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(bool ok, {String extra = ''}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Shortcut request sent ✅ $extra' : 'Failed ❌')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Icon Changer'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: activePackId,
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: const SizedBox(),
              items: availableIconPacks
                  .map((id) => DropdownMenuItem(
                        value: id,
                        child: Text(_packDisplayName(id)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => activePackId = value);
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Note: This uses the shortcut method — a confirmation dialog will appear on '
              'the Home Screen, and on some launchers a small badge may appear on the icon '
              'corner. This is Android security policy and cannot be removed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ),
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: demoApps.length,
              itemBuilder: (context, i) {
                final app = demoApps[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.android)),
                  title: Text(app.label),
                  subtitle: Text(app.packageName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.photo_library_outlined),
                        tooltip: 'Choose custom icon from gallery',
                        onPressed: () => _pickCustomIcon(app),
                      ),
                      FilledButton(
                        onPressed: () => _applyBundledOrCustomIcon(app),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
