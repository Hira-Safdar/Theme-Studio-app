import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/pack_selector.dart';
import '../widgets/widget_preview_card.dart';

/// IMPORTANT: Flutter khud "Home Screen widget" nahi bana sakta.
/// Home Screen widgets 100% native Android cheez hain (AppWidgetProvider),
/// jo Kotlin/XML me define hote hain. Flutter side sirf:
///   1. Widget ka data/config decide karta hai (kaunsa widget, kaunsi style)
///   2. requestPinAppWidget() call karke user ko "Add to Home Screen" ka
///      prompt deta hai
/// Actual widget draw karna, update karna -- sab kaam native
/// AppWidgetProvider + RemoteViews karta hai (android_native_files/ dekhein).

/// Style ek hi jagah se poore widget-family (Battery/Clock/Weather/
/// Calendar/Notes) par apply hoti hai -- Icon Changer ke "Auto" tab jaisa
/// hi pattern (ek shared control, sab par asar).
const List<String> widgetStyleOptions = ['minimal', 'gradient', 'neon'];

String _styleDisplayName(String id) {
  switch (id) {
    case 'gradient':
      return 'Gradient';
    case 'neon':
      return 'Neon Glass';
    default:
      return 'Minimal';
  }
}

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
    'weather': WidgetPinStatus.idle,
    'calendar': WidgetPinStatus.idle,
    'notes': WidgetPinStatus.idle,
  };

  String _style = widgetStyleOptions.first;

  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Drives the live clock/calendar preview — purely cosmetic, not tied
    // to the native widget, which renders itself once actually pinned.
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
        'style': _style,
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

  /// Style badalne par, jo widgets already pinned hain unhe bhi turant
  /// naye style mein re-render karwata hai (native side broadcast se) --
  /// taake user ko re-pin na karna pade sirf style dekhne ke liye.
  Future<void> _onStyleChanged(String style) async {
    setState(() => _style = style);
    final pinnedTypes = _status.entries
        .where((e) => e.value == WidgetPinStatus.pinned)
        .map((e) => e.key);
    for (final widgetType in pinnedTypes) {
      try {
        await _channel.invokeMethod('updateWidgetStyle', {
          'widgetType': widgetType,
          'style': style,
        });
      } on PlatformException {
        // Silent -- agla pin/interaction pe sahi style apply ho hi jayegi.
      }
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
          const SizedBox(height: AppSpacing.md),
          PackSelector(
            options: widgetStyleOptions,
            selected: _style,
            onChanged: _onStyleChanged,
            labelBuilder: _styleDisplayName,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          WidgetPreviewCard(
            name: 'Battery widget',
            preview: _StyledWidgetPreview(
              style: _style,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.battery_charging_full, color: AppColors.accentPrimary, size: 28),
                  SizedBox(height: 4),
                  Text('78%', style: AppTypography.body),
                ],
              ),
            ),
            status: _status['battery']!,
            onPin: () => _requestPinWidget('battery'),
            onRetry: () => _requestPinWidget('battery'),
          ),
          WidgetPreviewCard(
            name: 'Clock widget',
            preview: _StyledWidgetPreview(
              style: _style,
              child: Text(
                '${_pad(_now.hour)}:${_pad(_now.minute)}',
                style: AppTypography.display,
              ),
            ),
            status: _status['clock']!,
            onPin: () => _requestPinWidget('clock'),
            onRetry: () => _requestPinWidget('clock'),
          ),
          WidgetPreviewCard(
            name: 'Weather widget',
            preview: _StyledWidgetPreview(
              style: _style,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('24°', style: AppTypography.display),
                  SizedBox(height: 2),
                  Text('Partly cloudy', style: AppTypography.bodySecondary),
                ],
              ),
            ),
            status: _status['weather']!,
            onPin: () => _requestPinWidget('weather'),
            onRetry: () => _requestPinWidget('weather'),
          ),
          WidgetPreviewCard(
            name: 'Calendar widget',
            preview: _StyledWidgetPreview(
              style: _style,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_dayName(_now), style: AppTypography.bodySecondary),
                  Text('${_now.day}', style: AppTypography.display),
                ],
              ),
            ),
            status: _status['calendar']!,
            onPin: () => _requestPinWidget('calendar'),
            onRetry: () => _requestPinWidget('calendar'),
          ),
          WidgetPreviewCard(
            name: 'Notes widget',
            preview: _StyledWidgetPreview(
              style: _style,
              child: const Text(
                'Tap to add a note',
                textAlign: TextAlign.center,
                style: AppTypography.bodySecondary,
              ),
            ),
            status: _status['notes']!,
            onPin: () => _requestPinWidget('notes'),
            onRetry: () => _requestPinWidget('notes'),
          ),
        ],
      ),
    );
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');

const _weekdayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
String _dayName(DateTime d) => _weekdayNames[d.weekday - 1];

/// Live-rendered mini preview — demo values only. Real widget content
/// native side (RemoteViews) draw karta hai jab actually pinned ho.
/// [style] ke hisaab se background/border/glow badalta hai -- native
/// [WidgetStyleHelper] ke 3 drawables (minimal/gradient/neon) ka Flutter
/// equivalent, taake preview waisa hi dikhe jaisa asal widget pin hone
/// ke baad hoga.
class _StyledWidgetPreview extends StatelessWidget {
  const _StyledWidgetPreview({required this.style, required this.child});

  final String style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case 'gradient':
        return Container(
          width: 140,
          height: 90,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accentPrimary, Color(0xFF8B7CFF)],
            ),
          ),
          child: child,
        );

      case 'neon':
        return Container(
          width: 140,
          height: 90,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A12),
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );

      default: // minimal
        return Container(
          width: 140,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceRaised,
            borderRadius: AppRadius.mdRadius,
          ),
          alignment: Alignment.center,
          child: child,
        );
    }
  }
}