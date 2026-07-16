import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IMPORTANT: Flutter khud "Home Screen widget" nahi bana sakta.
/// Home Screen widgets 100% native Android cheez hain (AppWidgetProvider),
/// jo Kotlin/XML me define hote hain. Flutter side sirf:
///   1. Widget ka data/config decide karta hai (kaunsa style, kaunsa color)
///   2. requestPinAppWidget() call karke user ko "Add to Home Screen" ka
///      prompt deta hai
/// Actual widget draw karna, update karna -- sab kaam native
/// AppWidgetProvider + RemoteViews karta hai (android_native_files/ dekhein).
class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  static const _channel = MethodChannel('com.example.theme_studio/native');

  Future<void> _requestPinWidget(BuildContext context, String widgetType) async {
    try {
      final ok = await _channel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType, // e.g. "battery" ya "clock"
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok == true
            ? 'A prompt to add the widget to Home Screen will appear'
            : 'This launcher does not support widget pinning')),
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widgets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white10,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Widgets are native Android components (AppWidgetProvider). '
                'This screen only sends a request to "add to Home Screen" — '
                'the actual widget design is already built on the Kotlin/XML side.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.battery_full),
            title: const Text('Battery Widget'),
            trailing: FilledButton(
              onPressed: () => _requestPinWidget(context, 'battery'),
              child: const Text('Add'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Clock Widget'),
            trailing: FilledButton(
              onPressed: () => _requestPinWidget(context, 'clock'),
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
