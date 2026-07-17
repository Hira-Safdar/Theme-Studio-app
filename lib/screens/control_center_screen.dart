import 'package:flutter/material.dart';
import '../services/native_bridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accessibility_status_card.dart';
import '../widgets/accessibility_instructions_sheet.dart';

/// Control Center ek overlay hai jo Accessibility Service ke through screen
/// ke upar draw hota hai. Ye current launcher ko replace NAHI karta -- bas
/// uske upar float karta hai. Isliye ye kisi bhi launcher ke sath kaam karta hai.
class ControlCenterScreen extends StatefulWidget {
  const ControlCenterScreen({super.key});
  @override
  State<ControlCenterScreen> createState() => _ControlCenterScreenState();
}

class _ControlCenterScreenState extends State<ControlCenterScreen>
    with WidgetsBindingObserver {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Jab user Settings se wapas app par aaye, status dobara check karo.
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  Future<void> _checkStatus() async {
    final enabled = await NativeBridgeService.instance.isAccessibilityServiceEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  /// Shows the in-app "here's what to look for" guide first, since we
  /// can't draw any hint on Android's real settings screen (Android blocks
  /// overlays there for security — see accessibility_instructions_sheet.dart).
  /// Only after the user taps "Open Settings" in that guide do we actually
  /// hand off to Android.
  void _startTurnOnFlow() {
    AccessibilityInstructionsSheet.show(
      context,
      onOpenSettings: () => NativeBridgeService.instance.openAccessibilitySettings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control center')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          AccessibilityStatusCard(
            enabled: _enabled,
            onOpenSettings: _startTurnOnFlow,
          ),
        ],
      ),
    );
  }
}