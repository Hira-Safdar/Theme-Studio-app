import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/pack_selector.dart';
import '../services/native_bridge_service.dart';

/// IMPORTANT: Flutter khud "Home Screen widget" nahi bana sakta.
/// Home Screen widgets 100% native Android cheez hain (AppWidgetProvider),
/// jo Kotlin/XML me define hote hain. Flutter side sirf:
///   1. Widget ka data/config decide karta hai (kaunsa widget, kaunsi
///      style, kaunsa mode -- dark/light)
///   2. requestPinAppWidget() call karke user ko "Add to Home Screen" ka
///      prompt deta hai
/// Actual widget draw karna, update karna -- sab kaam native
/// AppWidgetProvider + RemoteViews karta hai.

/// Style + mode ek hi jagah se poore widget-family (Battery/Clock/Weather/
/// Calendar/Notes) par apply hote hain -- Icon Changer ke "Auto" tab jaisa
/// hi pattern (ek shared control, sab par asar).
const List<String> widgetStyleOptions = ['minimal', 'gradient', 'neon'];
const List<String> widgetModeOptions = ['dark', 'light'];

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

String _modeDisplayName(String id) => id == 'light' ? 'Light' : 'Dark';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.example.theme_studio/native');

  final Map<String, WidgetPinStatus> _status = {
    'battery': WidgetPinStatus.idle,
    'clock': WidgetPinStatus.idle,
    'weather': WidgetPinStatus.idle,
    'calendar': WidgetPinStatus.idle,
    'notes': WidgetPinStatus.idle,
  };

  String _style = widgetStyleOptions.first;
  String _mode = widgetModeOptions.first;

  // Har widget type ke live pinned-instance count -- AppWidgetManager se
  // aata hai, isliye add/remove (Home Screen se seedha remove kiya gaya
  // ho tab bhi) dono khud-ba-khud sahi reflect hote hain jab bhi refresh
  // hoti hai.
  Map<String, int> _pinnedCounts = {};

  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  // Weather: real (approx) location, resolved once permission is granted.
  String? _weatherLocation;
  bool _weatherLocationLoading = false;

  // Real cached temp/condition (Open-Meteo, via native) -- null tak
  // location fetch complete nahi hoti, tab tak card loading state dikhati hai.
  String? _weatherTemp;
  String? _weatherCondition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drives the live clock/calendar preview — purely cosmetic, not tied
    // to the native widget, which renders itself once actually pinned.
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _initWeatherLocation();
    _refreshPinnedCounts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User Settings ya Home Screen (widget pin/remove) se wapas is screen
    // par aaye to counts + weather refresh kar dete hain -- taake stale
    // na dikhayein. Notes ka apna "saved text" track nahi karte -- wo
    // device ke real Notes app mein hai, jise Theme Studio padh nahi sakti.
    if (state == AppLifecycleState.resumed) {
      _refreshPinnedCounts();
      _refreshWeatherSnapshot();
    }
  }

  Future<void> _refreshPinnedCounts() async {
    final counts = await NativeBridgeService.instance.getPinnedWidgetCounts();
    if (!mounted) return;
    setState(() => _pinnedCounts = counts);
  }

  /// Android koi public API nahi deta jisse ek app apne khud ke pinned
  /// widget ko force-remove kar sake -- sirf user (launcher se long-press
  /// > Remove) ye kar sakta hai. Isliye "remove" button yahan clear
  /// instructions dikhata hai instead of ek na-mumkin direct-delete.
  void _showRemoveInstructions(String widgetName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove $widgetName widget'),
        content: const Text(
          'Android doesn\'t let apps remove widgets directly. On your '
          'Home Screen, long-press the widget and tap Remove -- the count '
          'here will update next time you open this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Pehle device ke real Notes app (ya jo bhi OEM Notes app resolve ho)
  /// kholne ki koshish karta hai -- pinned widget tap wala hi flow, taake
  /// in-app card se bhi hamesha "apna mobile ka Notes app" khule. Koi
  /// notes app na mile to native side khud hamari fallback editor
  /// (NotesEditorScreen) khol deta hai.
  Future<void> _openNoteEditor() async {
    await NativeBridgeService.instance.openNotesApp();
  }

  Future<void> _initWeatherLocation() async {
    setState(() => _weatherLocationLoading = true);
    var status = await Permission.location.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.location.request();
    }
    if (!mounted) return;
    if (status.isGranted) {
      final label = await NativeBridgeService.instance.getWeatherLocation();
      if (!mounted) return;
      setState(() {
        _weatherLocation = label;
        _weatherLocationLoading = false;
      });
      // Location fetch ke turant baad native side temp/condition bhi
      // cache kar chuka hota hai -- ab wahi padh lete hain.
      _refreshWeatherSnapshot();
    } else {
      setState(() => _weatherLocationLoading = false);
    }
  }

  Future<void> _refreshWeatherSnapshot() async {
    final snapshot = await NativeBridgeService.instance.getWeatherSnapshot();
    if (!mounted) return;
    setState(() {
      _weatherTemp = snapshot['temperature'];
      _weatherCondition = snapshot['condition'];
    });
  }

  Future<void> _requestPinWidget(String widgetType) async {
    setState(() => _status[widgetType] = WidgetPinStatus.requesting);

    try {
      final ok = await _channel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType,
        'style': _style,
        'mode': _mode,
      });

      if (!mounted) return;

      if (ok == true) {
        // Optimistic — Android doesn't reliably report back once the
        // system dialog is dismissed, so we mark it pinned here rather
        // than waiting for a confirmation that may never arrive.
        setState(() => _status[widgetType] = WidgetPinStatus.pinned);
        _refreshPinnedCounts();
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

  /// Style ya mode badalne par, jo widgets already pinned hain unhe bhi
  /// turant naye look mein re-render karwata hai (native side broadcast
  /// se) -- taake user ko re-pin na karna pade sirf style/mode dekhne ke
  /// liye.
  Future<void> _pushStyleUpdateToPinned() async {
    final pinnedTypes = _status.entries
        .where((e) => e.value == WidgetPinStatus.pinned)
        .map((e) => e.key);
    for (final widgetType in pinnedTypes) {
      try {
        await _channel.invokeMethod('updateWidgetStyle', {
          'widgetType': widgetType,
          'style': _style,
          'mode': _mode,
        });
      } on PlatformException {
        // Silent -- agla pin/interaction pe sahi style apply ho hi jayegi.
      }
    }
  }

  void _onStyleChanged(String style) {
    setState(() => _style = style);
    _pushStyleUpdateToPinned();
  }

  void _onModeChanged(String mode) {
    setState(() => _mode = mode);
    _pushStyleUpdateToPinned();
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

          // Style + Appearance side-by-side — two compact controls instead
          // of a stack of full-width cards, so the top of the screen stays
          // short and scannable.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _LabeledControl(
                  label: 'Style',
                  child: PackSelector(
                    options: widgetStyleOptions,
                    selected: _style,
                    onChanged: _onStyleChanged,
                    labelBuilder: _styleDisplayName,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: _LabeledControl(
                  label: 'Appearance',
                  child: PackSelector(
                    options: widgetModeOptions,
                    selected: _mode,
                    onChanged: _onModeChanged,
                    labelBuilder: _modeDisplayName,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2-column grid of compact cards — same info as before (preview +
          // name + pin action), just far less vertical scroll than five
          // stacked full-width cards.
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.82,
            ),
            children: [
              _CompactWidgetCard(
                name: 'Battery',
                preview: _StyledWidgetPreview(
                  style: _style,
                  mode: _mode,
                  builder: (textColor, secondaryColor, iconColor) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.battery_charging_full, color: iconColor, size: 22),
                      const SizedBox(height: 4),
                      Text('78%', style: AppTypography.body.copyWith(color: textColor)),
                    ],
                  ),
                ),
                status: _status['battery']!,
                pinnedCount: _pinnedCounts['battery'] ?? 0,
                onTap: () => _requestPinWidget('battery'),
                onRemove: () => _showRemoveInstructions('Battery'),
              ),
              _CompactWidgetCard(
                name: 'Clock',
                preview: _StyledWidgetPreview(
                  style: _style,
                  mode: _mode,
                  builder: (textColor, secondaryColor, iconColor) => Text(
                    '${_pad(_now.hour)}:${_pad(_now.minute)}',
                    style: AppTypography.heading.copyWith(color: textColor),
                  ),
                ),
                status: _status['clock']!,
                pinnedCount: _pinnedCounts['clock'] ?? 0,
                onTap: () => _requestPinWidget('clock'),
                onRemove: () => _showRemoveInstructions('Clock'),
              ),
              _CompactWidgetCard(
                name: 'Weather',
                preview: _StyledWidgetPreview(
                  style: _style,
                  mode: _mode,
                  builder: (textColor, secondaryColor, iconColor) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_weatherTemp ?? '--°', style: AppTypography.body.copyWith(color: textColor)),
                      const SizedBox(height: 2),
                      Text(
                        _weatherCondition ?? 'Waiting for location…',
                        style: AppTypography.bodySecondary.copyWith(color: secondaryColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                status: _status['weather']!,
                pinnedCount: _pinnedCounts['weather'] ?? 0,
                onTap: () => _requestPinWidget('weather'),
                onRemove: () => _showRemoveInstructions('Weather'),
                footnote: _weatherLocationLoading
                    ? 'Locating…'
                    : (_weatherLocation ?? 'Location unavailable'),
                footnoteIcon: Icons.location_on_outlined,
                onFootnoteTap: _weatherLocationLoading ? null : _initWeatherLocation,
              ),
              _CompactWidgetCard(
                name: 'Calendar',
                preview: _StyledWidgetPreview(
                  style: _style,
                  mode: _mode,
                  builder: (textColor, secondaryColor, iconColor) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayName(_now), style: AppTypography.bodySecondary.copyWith(color: secondaryColor)),
                      Text('${_now.day}', style: AppTypography.body.copyWith(color: textColor)),
                    ],
                  ),
                ),
                status: _status['calendar']!,
                pinnedCount: _pinnedCounts['calendar'] ?? 0,
                onTap: () => _requestPinWidget('calendar'),
                onRemove: () => _showRemoveInstructions('Calendar'),
              ),
              _CompactWidgetCard(
                name: 'Notes',
                preview: _StyledWidgetPreview(
                  style: _style,
                  mode: _mode,
                  builder: (textColor, secondaryColor, iconColor) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, color: iconColor, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open Notes',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySecondary.copyWith(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                status: _status['notes']!,
                pinnedCount: _pinnedCounts['notes'] ?? 0,
                onTap: () => _requestPinWidget('notes'),
                onRemove: () => _showRemoveInstructions('Notes'),
                footnote: 'Open Notes app',
                footnoteIcon: Icons.edit_outlined,
                onFootnoteTap: _openNoteEditor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _pad(int n) => n.toString().padLeft(2, '0');

const _weekdayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
String _dayName(DateTime d) => _weekdayNames[d.weekday - 1];

/// Small caption + control pairing, used for the Style/Appearance row so
/// each control is self-explanatory without needing a full section header.
class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(label, style: AppTypography.bodySecondary),
        ),
        child,
      ],
    );
  }
}

/// Compact grid card — smaller preview, single-line name, and a small pill
/// for the pin action, plus an optional footnote row (used by Weather for
/// location, Notes for "Edit note") so per-widget extras don't need their
/// own full section.
class _CompactWidgetCard extends StatelessWidget {
  const _CompactWidgetCard({
    required this.name,
    required this.preview,
    required this.status,
    required this.pinnedCount,
    required this.onTap,
    required this.onRemove,
    this.footnote,
    this.footnoteIcon,
    this.onFootnoteTap,
  });

  final String name;
  final Widget preview;
  final WidgetPinStatus status;
  final int pinnedCount;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final String? footnote;
  final IconData? footnoteIcon;
  final VoidCallback? onFootnoteTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppElevation.level1(radius: AppRadius.mdRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Center(child: preview)),
          const SizedBox(height: AppSpacing.sm),
          Text(name, style: AppTypography.label, textAlign: TextAlign.center),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            GestureDetector(
              onTap: onFootnoteTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (footnoteIcon != null)
                    Icon(footnoteIcon, size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      footnote!,
                      style: AppTypography.bodySecondary.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Home Screen par is waqt kitne pinned hain -- 0 hone par
          // kuch nahi dikhate (koi remove karne ko hai hi nahi).
          if (pinnedCount > 0) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    pinnedCount == 1 ? '1 on Home Screen' : '$pinnedCount on Home Screen',
                    style: AppTypography.bodySecondary.copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.close, size: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _PinPill(status: status, onTap: onTap),
        ],
      ),
    );
  }
}

class _PinPill extends StatelessWidget {
  const _PinPill({required this.status, required this.onTap});

  final WidgetPinStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case WidgetPinStatus.requesting:
        return const SizedBox(
          height: 30,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.textSecondary),
              ),
            ),
          ),
        );
      case WidgetPinStatus.pinned:
        return OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(30),
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 13, color: AppColors.success),
              SizedBox(width: 4),
              Text('Pinned'),
            ],
          ),
        );
      case WidgetPinStatus.idle:
        return OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(30),
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(fontSize: 11),
          ),
          child: const Text('Pin'),
        );
    }
  }
}

enum WidgetPinStatus { idle, requesting, pinned }

/// Live-rendered mini preview — demo values only (except Weather's location
/// footnote and Notes' saved text, which are real). Real widget content
/// native side (RemoteViews) draw karta hai jab actually pinned ho.
/// [style] + [mode] ke hisaab se background badalta hai, aur [builder] ko
/// explicit textColor/secondaryColor/iconColor deta hai -- taake har widget
/// apne content ko sahi (light-mode par bhi visible) colors se render kare,
/// AppTypography ke built-in dark-mode color par silently depend kiye
/// bagair. Native [WidgetStyleHelper] ke 6 combos ka Flutter equivalent.
class _StyledWidgetPreview extends StatelessWidget {
  const _StyledWidgetPreview({
    required this.style,
    required this.mode,
    required this.builder,
  });

  final String style;
  final String mode;
  final Widget Function(Color textColor, Color secondaryColor, Color iconColor) builder;

  bool get _isLight => mode == 'light';

  @override
  Widget build(BuildContext context) {
    final textColor = _isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final secondaryColor = _isLight ? const Color(0xFF4A4A4A) : AppColors.textSecondary;
    final iconColor =
        _isLight ? const Color(0xFF007A72) : AppColors.accentPrimary;
    final content = builder(textColor, secondaryColor, iconColor);

    switch (style) {
      case 'gradient':
        return Container(
          width: 96,
          height: 70,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isLight
                  ? const [Color(0xFFB8FFF9), Color(0xFFDBD6FF)]
                  : [AppColors.accentPrimary, const Color(0xFF8B7CFF)],
            ),
          ),
          child: content,
        );

      case 'neon':
        return Container(
          width: 96,
          height: 70,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isLight ? const Color(0xFFF4FDFC) : const Color(0xFF0A0A12),
            borderRadius: AppRadius.mdRadius,
            border: Border.all(
              color: (_isLight ? const Color(0xFF00B8AE) : AppColors.accentPrimary)
                  .withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: content,
        );

      default: // minimal
        return Container(
          width: 96,
          height: 70,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isLight ? const Color(0xFFF2EFEC) : AppColors.bgSurfaceRaised,
            borderRadius: AppRadius.mdRadius,
          ),
          alignment: Alignment.center,
          child: content,
        );
    }
  }
}