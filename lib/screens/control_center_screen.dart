import 'package:flutter/material.dart';
import '../services/native_bridge_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control Center')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _enabled ? Icons.check_circle : Icons.warning_amber,
                  color: _enabled ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                Text(_enabled
                    ? 'Accessibility Service is ON'
                    : 'Accessibility Service is OFF'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Accessibility permission is required to show the Control Center overlay. '
              'This must be turned on manually, once, in Settings — Android does not '
              'allow apps to enable this automatically.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (!_enabled)
              FilledButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Open Accessibility Settings'),
                onPressed: () => NativeBridgeService.instance.openAccessibilitySettings(),
              ),
            if (_enabled)
              const Card(
                color: Colors.white10,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'You can now swipe down from the top of the screen to test '
                    'the Control Center overlay (native ControlCenterAccessibilityService.kt '
                    'detects this gesture).',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
