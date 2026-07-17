// lib/widgets/accessibility_status_card.dart
//
// Accessibility status card — colored dot + ON/OFF label + one context
// line; button to deep-link to Android Accessibility settings only shown
// when OFF; overlay preview replaces the button when ON. §2 + §3.6.
//
// Copy is calm setup-framing, never apologetic ("Turn on once in Android
// Settings — takes about 10 seconds", not "unfortunately you must...").

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AccessibilityStatusCard extends StatelessWidget {
  const AccessibilityStatusCard({
    super.key,
    required this.enabled,
    required this.onOpenSettings,
  });

  final bool enabled;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppElevation.level1(radius: AppRadius.lgRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: enabled
                ? 'Overlay is on. Control Center is ready to use.'
                : 'Overlay is off. Turn it on to use Control Center.',
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.success : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  enabled ? 'Overlay: on' : 'Overlay: off',
                  style: AppTypography.heading,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            enabled
                ? 'Swipe down from the top of the screen to open Control Center.'
                : 'Control Center needs the accessibility service running to draw its overlay.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Never show both the button and the preview at once.
          if (!enabled)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenSettings,
                child: const Text('Turn on once in Android Settings — takes about 10 seconds'),
              ),
            )
          else
            const _OverlayPreview(),
        ],
      ),
    );
  }
}

/// Non-interactive miniature of the Control Center overlay sheet, shown
/// once the accessibility service is on — replaces the setup button.
class _OverlayPreview extends StatelessWidget {
  const _OverlayPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.bgOverlay,
        borderRadius: AppRadius.sheetRadius,
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: AppRadius.smRadius,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _tile(Icons.wifi, active: true)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _tile(Icons.bluetooth, active: true)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _tile(Icons.flashlight_on, active: false)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _tile(Icons.brightness_6, active: false)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: AppRadius.smRadius,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: active ? AppColors.accentPrimaryMuted : AppColors.bgSurface,
        borderRadius: AppRadius.mdRadius,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: active ? AppColors.accentPrimary : AppColors.textSecondary,
        size: 20,
      ),
    );
  }
}