import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/pack_selector.dart';
import '../widgets/widget_preview_card.dart' show WidgetPinStatus;
import '../services/app_strings.dart';
import '../services/native_bridge_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'notes_editor_screen.dart';
import 'weather_location_screen.dart';

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

  final Map<String, WidgetPinStatus> _status = {
    'battery': WidgetPinStatus.idle,
    'clock': WidgetPinStatus.idle,
    'weather': WidgetPinStatus.idle,
    'calendar': WidgetPinStatus.idle,
    'notes': WidgetPinStatus.idle,
  };

  String _style = widgetStyleOptions.first;
  String _mode = widgetModeOptions.first;

  // Widget customization params -- font size, text color, bg opacity, corner
  // radius. Defaults are chosen to match the existing minimal dark style.
  double _widgetFontSize = 16.0;
  Color _widgetTextColor = Colors.white;
  double _widgetBgOpacity = 0.85;
  double _widgetCornerRadius = 12.0;
  bool _customizationLoaded = false;

  static const List<Color> _textColorPresets = [
    Colors.white,
    Color(0xFF1A1A1A),
    Color(0xFF00FFF0),
    Color(0xFFFF7A59),
    Color(0xFF8B7CFF),
    Color(0xFF4FD8B8),
  ];

  // Har widget type ke live pinned-instance count -- AppWidgetManager se
  // aata hai, isliye add/remove (Home Screen se seedha remove kiya gaya
  // ho tab bhi) dono khud-ba-khud sahi reflect hote hain jab bhi refresh
  // hoti hai.
  Map<String, int> _pinnedCounts = {};

  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  // Weather: whatever the user last chose in the Weather Location screen --
  // no GPS, no silent auto-detect. Kabhi choose na ki ho to null, aur UI
  // "Location unavailable" dikhati hai (tap se picker screen khulti hai).
  String? _weatherLocation;
  bool _weatherLocationLoading = false;

  // Real cached temp/condition (Open-Meteo, via native) -- null tak
  // location fetch complete nahi hoti, tab tak card loading state dikhati hai.
  String? _weatherTemp;
  String? _weatherCondition;

  // Notes: reflects whatever is actually saved (from the in-app editor or
  // the native fallback flow), not a static placeholder.
  String? _noteText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Drives the live clock/calendar preview — purely cosmetic, not tied
    // to the native widget, which renders itself once actually pinned.
    _startClockTicker();
    _refreshNoteText();
    _initWeatherLocation();
    _refreshPinnedCounts();
    _loadCustomization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User Settings, Notes editor, ya Home Screen (widget pin/remove) se
    // wapas is screen par aaye to sab kuch refresh kar dete hain -- taake
    // preview + counts hamesha asal saved state dikhayein, stale nahi.
    if (state == AppLifecycleState.resumed) {
      _refreshNoteText();
      _refreshPinnedCounts();
      _refreshWeatherSnapshot();
      // App foreground par aaya -- clock ticker dobara start karo.
      _startClockTicker();
    } else {
      // App background mein ja raha hai -- clock ticker roko, battery bachao.
      _clockTicker?.cancel();
      _clockTicker = null;
    }
  }

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _refreshPinnedCounts() async {
    final counts = await NativeBridgeService.instance.getPinnedWidgetCounts();
    if (!mounted) return;
    setState(() => _pinnedCounts = counts);
  }

  Future<void> _loadCustomization() async {
    final data = await NativeBridgeService.instance.getWidgetCustomization();
    if (!mounted) return;
    setState(() {
      _widgetFontSize = (data['fontSize'] as num?)?.toDouble() ?? 16.0;
      final hex = data['textColor'] as String?;
      _widgetTextColor = hex != null ? Color(int.parse(hex.replaceFirst('#', '0xFF'))) : Colors.white;
      _widgetBgOpacity = (data['bgOpacity'] as num?)?.toDouble() ?? 0.85;
      _widgetCornerRadius = (data['cornerRadius'] as num?)?.toDouble() ?? 12.0;
      _customizationLoaded = true;
    });
  }

  Future<void> _saveCustomization() async {
    try {
      await NativeBridgeService.instance.saveWidgetCustomization(
        fontSize: _widgetFontSize,
        textColorHex: '#${_widgetTextColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        bgOpacity: _widgetBgOpacity,
        cornerRadius: _widgetCornerRadius,
      );
    } catch (_) {}
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

  Future<void> _refreshNoteText() async {
    final text = await NativeBridgeService.instance.getNoteText();
    if (!mounted) return;
    setState(() => _noteText = text);
  }

  Future<void> _openNoteEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotesEditorScreen()),
    );
    _refreshNoteText();
  }

  /// Sirf cached label padhta hai -- na GPS, na permission prompt, na
  /// network call. Widgets screen khulte hi (ya resume par) ye chalta hai
  /// taake koi surprising "location khud badal gayi" na ho, sirf jo user
  /// ne Weather Location screen mein khud choose ki thi wahi dikhe.
  Future<void> _initWeatherLocation() async {
    setState(() => _weatherLocationLoading = true);
    final label = await NativeBridgeService.instance.getSavedWeatherLocation();
    if (!mounted) return;
    setState(() {
      _weatherLocation = label;
      _weatherLocationLoading = false;
    });
    _refreshWeatherSnapshot();
  }

  /// Tap par humari apni "choose location" screen khulti hai -- wahan se
  /// wapas aane par yahan ka footnote/temp turant refresh ho jaata hai.
  Future<void> _openWeatherLocationScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeatherLocationScreen()),
    );
    _initWeatherLocation();
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
      final ok = await NativeBridgeService.instance.requestPinWidget(
        widgetType: widgetType,
        style: _style,
        mode: _mode,
        fontSize: _widgetFontSize,
        textColorHex: '#${_widgetTextColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        bgOpacity: _widgetBgOpacity,
        cornerRadius: _widgetCornerRadius,
      );

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
    final textColorHex = '#${_widgetTextColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    for (final widgetType in pinnedTypes) {
      await NativeBridgeService.instance.updateWidgetStyle(
        widgetType: widgetType,
        style: _style,
        mode: _mode,
        fontSize: _widgetFontSize,
        textColorHex: textColorHex,
        bgOpacity: _widgetBgOpacity,
        cornerRadius: _widgetCornerRadius,
      );
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
      appBar: AppBar(title: Text(tr('widgets_title'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
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

          // Widget customization controls -- font size, text color,
          // background opacity, corner radius. These params are persisted
          // via SharedPreferences and passed to native side on pin/update.
          if (_customizationLoaded) ...[
            _LabeledControl(
              label: tr('widget_font_size'),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _widgetFontSize,
                      min: 12,
                      max: 32,
                      divisions: 20,
                      label: _widgetFontSize.round().toString(),
                      onChanged: (v) {
                        setState(() => _widgetFontSize = v);
                        _saveCustomization();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${_widgetFontSize.round()}',
                      style: AppTypography.bodySecondary,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledControl(
              label: tr('widget_text_color'),
              child: Row(
                children: _textColorPresets.map((color) {
                  final isSelected = color.toARGB32() == _widgetTextColor.toARGB32();
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _widgetTextColor = color);
                        _saveCustomization();
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppTheme.textPrimary(context) : AppTheme.surfaceRaised(context),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: color.toARGB32() == Colors.white.toARGB32()
                                    ? Colors.black87
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledControl(
              label: tr('widget_bg_opacity'),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _widgetBgOpacity,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(_widgetBgOpacity * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _widgetBgOpacity = v);
                        _saveCustomization();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(_widgetBgOpacity * 100).round()}%',
                      style: AppTypography.bodySecondary,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledControl(
              label: tr('widget_corner_radius'),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _widgetCornerRadius,
                      min: 0,
                      max: 24,
                      divisions: 12,
                      label: _widgetCornerRadius.round().toString(),
                      onChanged: (v) {
                        setState(() => _widgetCornerRadius = v);
                        _saveCustomization();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${_widgetCornerRadius.round()}',
                      style: AppTypography.bodySecondary,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

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
                  fontSize: _widgetFontSize,
                  textColor: _widgetTextColor,
                  bgOpacity: _widgetBgOpacity,
                  cornerRadius: _widgetCornerRadius,
                  builder: (fs, textColor, secondaryColor, iconColor) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.battery_charging_full, color: iconColor, size: 22),
                      const SizedBox(height: 4),
                      Text('78%', style: AppTypography.body.copyWith(color: textColor, fontSize: fs)),
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
                  fontSize: _widgetFontSize,
                  textColor: _widgetTextColor,
                  bgOpacity: _widgetBgOpacity,
                  cornerRadius: _widgetCornerRadius,
                  builder: (fs, textColor, secondaryColor, iconColor) => Text(
                    '${_pad(_now.hour)}:${_pad(_now.minute)}',
                    style: AppTypography.heading.copyWith(color: textColor, fontSize: fs),
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
                  fontSize: _widgetFontSize,
                  textColor: _widgetTextColor,
                  bgOpacity: _widgetBgOpacity,
                  cornerRadius: _widgetCornerRadius,
                  builder: (fs, textColor, secondaryColor, iconColor) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_weatherTemp ?? '--°', style: AppTypography.body.copyWith(color: textColor, fontSize: fs)),
                        const SizedBox(height: 2),
                        Text(
                          _weatherCondition ?? 'Waiting for location…',
                          style: AppTypography.bodySecondary.copyWith(color: secondaryColor, fontSize: fs * 0.85),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                status: _status['weather']!,
                pinnedCount: _pinnedCounts['weather'] ?? 0,
                onTap: () => _requestPinWidget('weather'),
                onRemove: () => _showRemoveInstructions('Weather'),
                footnote: _weatherLocationLoading
                    ? 'Loading…'
                    : (_weatherLocation ?? 'Choose location'),
                footnoteIcon: Icons.location_on_outlined,
                onFootnoteTap: _weatherLocationLoading ? null : _openWeatherLocationScreen,
              ),
              _CompactWidgetCard(
                name: 'Calendar',
                preview: _StyledWidgetPreview(
                  style: _style,
                  mode: _mode,
                  fontSize: _widgetFontSize,
                  textColor: _widgetTextColor,
                  bgOpacity: _widgetBgOpacity,
                  cornerRadius: _widgetCornerRadius,
                  builder: (fs, textColor, secondaryColor, iconColor) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayName(_now), style: AppTypography.bodySecondary.copyWith(color: secondaryColor, fontSize: fs * 0.85)),
                      Text('${_now.day}', style: AppTypography.body.copyWith(color: textColor, fontSize: fs)),
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
                  fontSize: _widgetFontSize,
                  textColor: _widgetTextColor,
                  bgOpacity: _widgetBgOpacity,
                  cornerRadius: _widgetCornerRadius,
                  builder: (fs, textColor, secondaryColor, iconColor) => Text(
                    (_noteText == null || _noteText!.trim().isEmpty)
                        ? 'Tap to add a note'
                        : _noteText!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySecondary.copyWith(color: secondaryColor, fontSize: fs),
                  ),
                ),
                status: _status['notes']!,
                pinnedCount: _pinnedCounts['notes'] ?? 0,
                onTap: () => _requestPinWidget('notes'),
                onRemove: () => _showRemoveInstructions('Notes'),
                footnote: 'Edit note',
                footnoteIcon: Icons.edit_outlined,
                onFootnoteTap: _openNoteEditor,
              ),
            ],
          ),
        ],
      ),
      ),
          const Center(child: BannerAdWidget(placement: 'widgets')),
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
      decoration: AppTheme.level1(context, radius: AppRadius.mdRadius),
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
                    Icon(footnoteIcon, size: 11, color: AppTheme.textSecondary(context)),
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
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(Icons.close, size: 12, color: AppTheme.textSecondary(context)),
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
        return SizedBox(
          height: 30,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppTheme.textSecondary(context)),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, size: 13, color: AppTheme.success(context)),
              const SizedBox(width: 4),
              const Text('Pinned'),
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

class _StyledWidgetPreview extends StatelessWidget {
  const _StyledWidgetPreview({
    required this.style,
    required this.mode,
    required this.builder,
    this.fontSize,
    this.textColor,
    this.bgOpacity,
    this.cornerRadius,
  });

  final String style;
  final String mode;
  final Widget Function(double fontSize, Color textColor, Color secondaryColor, Color iconColor) builder;
  final double? fontSize;
  final Color? textColor;
  final double? bgOpacity;
  final double? cornerRadius;

  bool get _isLight => mode == 'light';

  BorderRadius _radius() => BorderRadius.all(Radius.circular(cornerRadius ?? 12));

  Color _bgBase() {
    switch (style) {
      case 'gradient':
        return Colors.transparent;
      case 'neon':
        return _isLight ? const Color(0xFFF4FDFC) : const Color(0xFF0A0A12);
      default:
        return _isLight ? const Color(0xFFF2EFEC) : AppColors.bgSurfaceRaised;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? (_isLight ? const Color(0xFF1A1A1A) : Colors.white);
    final secondaryColor = _isLight ? const Color(0xFF4A4A4A) : AppColors.textSecondary;
    final iconColor = _isLight ? const Color(0xFF007A72) : AppColors.accentPrimary;
    final fs = fontSize ?? 14.0;
    final content = builder(fs, effectiveTextColor, secondaryColor, iconColor);

    Widget styled;
    switch (style) {
      case 'gradient':
        styled = Container(
          width: 96,
          height: 70,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: _radius(),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: (_isLight
                      ? [const Color(0xFFB8FFF9), const Color(0xFFDBD6FF)]
                      : [AppColors.accentPrimary, const Color(0xFF8B7CFF)])
                  .map((c) => c.withValues(alpha: bgOpacity ?? 1))
                  .toList(),
            ),
          ),
          child: content,
        );
      case 'neon':
        styled = Container(
          width: 96,
          height: 70,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _bgBase().withValues(alpha: bgOpacity ?? 1),
            borderRadius: _radius(),
            border: Border.all(
              color: (_isLight ? const Color(0xFF00B8AE) : AppColors.accentPrimary).withValues(alpha: 0.6),
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
      default:
        styled = Container(
          width: 96,
          height: 70,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _bgBase().withValues(alpha: bgOpacity ?? 1),
            borderRadius: _radius(),
          ),
          alignment: Alignment.center,
          child: content,
        );
    }

    return styled;
  }
}