import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/widget_preview_card.dart';

/// IMPORTANT: Flutter khud "Home Screen widget" nahi bana sakta.
/// Home Screen widgets 100% native Android cheez hain (AppWidgetProvider),
/// jo Kotlin/XML me define hote hain. Flutter side sirf:
///   1. Widget ka data/config decide karta hai (kaunsa style, kaunsa color)
///   2. requestPinAppWidget() call karke user ko "Add to Home Screen" ka
///      prompt deta hai
/// Actual widget draw karna, update karna -- sab kaam native
/// AppWidgetProvider + RemoteViews karta hai (android_native_files/ dekhein).
class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  static const _channel = MethodChannel('com.example.theme_studio/native');

  final Map<String, WidgetPinStatus> _status = {
    'battery': WidgetPinStatus.idle,
    'clock': WidgetPinStatus.idle,
  };

  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Drives the live clock preview — purely cosmetic, not tied to the
    // native widget, which renders itself once actually pinned.
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

  Future<void> _requestPinWidget(String widgetType) async {
    setState(() => _status[widgetType] = WidgetPinStatus.requesting);

    try {
      final ok = await _channel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType,
      });

      if (!mounted) return;

      if (ok == true) {
        // Optimistic — Android doesn't reliably report back once the
        // system dialog is dismissed, so we mark it pinned here rather
        // than waiting for a confirmation that may never arrive.
        setState(() => _status[widgetType] = WidgetPinStatus.pinned);
      } else {
        setState(() => _status[widgetType] = WidgetPinStatus.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This launcher doesn't support widget pinning")),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status[widgetType] = WidgetPinStatus.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t request the widget — ${e.message ?? 'try again'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widgets')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          const Text(
            'Android will confirm before adding a widget.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          WidgetPreviewCard(
            name: 'Battery widget',
            preview: const _BatteryPreview(),
            status: _status['battery']!,
            onPin: () => _requestPinWidget('battery'),
            onRetry: () => _requestPinWidget('battery'),
          ),
          WidgetPreviewCard(
            name: 'Clock widget',
            preview: _ClockPreview(now: _now),
            status: _status['clock']!,
            onPin: () => _requestPinWidget('clock'),
            onRetry: () => _requestPinWidget('clock'),
          ),
        ],
      ),
    );
  }
}

/// Live-rendered mini preview — demo values only. The real widget content
/// (actual battery %, actual time) is drawn natively once pinned, via
/// AppWidgetProvider + RemoteViews.
class _BatteryPreview extends StatelessWidget {
  const _BatteryPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceRaised,
        borderRadius: AppRadius.mdRadius,
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_charging_full, color: AppColors.accentPrimary, size: 28),
          SizedBox(height: 4),
          Text('78%', style: AppTypography.body),
        ],
      ),
    );
  }
}

class _ClockPreview extends StatelessWidget {
  const _ClockPreview({required this.now});
  final DateTime now;

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceRaised,
        borderRadius: AppRadius.mdRadius,
      ),
      alignment: Alignment.center,
      child: Text(
        '${_pad(now.hour)}:${_pad(now.minute)}',
        style: AppTypography.display,
      ),
    );
  }
}