// lib/widgets/accessibility_instructions_sheet.dart
//
// Shown once, right before we hand off to Android's real Accessibility
// Settings screen. We cannot draw any hint/overlay/highlight on that real
// screen — Android deliberately disables the toggle if any app tries to
// overlay a system permission screen (anti-tapjacking protection). So the
// best we can do is show a clear "here's exactly what you'll see and what
// to tap" preview *inside our own app*, using a mock settings-row mockup
// with a pulsing highlight, before the user leaves for the real screen.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AccessibilityInstructionsSheet extends StatefulWidget {
  const AccessibilityInstructionsSheet({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  /// Shows the sheet. Returns after the sheet is dismissed either way.
  static Future<void> show(BuildContext context, {required VoidCallback onOpenSettings}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSurfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
      builder: (_) => AccessibilityInstructionsSheet(onOpenSettings: onOpenSettings),
    );
  }

  @override
  State<AccessibilityInstructionsSheet> createState() =>
      _AccessibilityInstructionsSheetState();
}

class _AccessibilityInstructionsSheetState extends State<AccessibilityInstructionsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _blinkOpacity;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _blinkOpacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.lg,
          AppSpacing.screenPadding,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.smRadius,
                ),
              ),
            ),
            const Text('Turn on Control Center', style: AppTypography.heading),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "Android will open its own Accessibility settings — here's exactly "
              'what to look for on that screen.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Mock preview of the real settings list, with the relevant
            // row pulsing so the user knows exactly what to find and tap.
            _MockSettingsList(blinkOpacity: _blinkOpacity),

            const SizedBox(height: AppSpacing.xl),

            const _StepRow(number: 1, text: 'Find "Theme Studio" in the list below'),
            const SizedBox(height: AppSpacing.md),
            const _StepRow(number: 2, text: 'Tap it to open its details'),
            const SizedBox(height: AppSpacing.md),
            const _StepRow(number: 3, text: 'Turn the switch on, then come back here'),

            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenSettings();
                },
                child: const Text('Open Settings'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small non-interactive mockup of what Android's Accessibility list
/// looks like, so the user recognizes the real screen when it opens.
/// This lives entirely inside our own app — it's not drawn over Android's
/// real settings (which isn't possible; see file header).
class _MockSettingsList extends StatelessWidget {
  const _MockSettingsList({required this.blinkOpacity});
  final Animation<double> blinkOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          const _MockRow(label: 'Downloaded apps', highlighted: false),
          const Divider(height: 1, indent: AppSpacing.lg),
          AnimatedBuilder(
            animation: blinkOpacity,
            builder: (context, child) => _MockRow(
              label: 'Theme Studio',
              highlighted: true,
              highlightOpacity: blinkOpacity.value,
            ),
          ),
          const Divider(height: 1, indent: AppSpacing.lg),
          const _MockRow(label: 'Other services', highlighted: false),
        ],
      ),
    );
  }
}

class _MockRow extends StatelessWidget {
  const _MockRow({
    required this.label,
    required this.highlighted,
    this.highlightOpacity = 1.0,
  });

  final String label;
  final bool highlighted;
  final double highlightOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: highlighted
          ? AppColors.accentPrimaryMuted.withValues(alpha: 0.5 * highlightOpacity)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            highlighted ? Icons.apps : Icons.circle_outlined,
            size: 18,
            color: highlighted
                ? AppColors.accentPrimary.withValues(alpha: highlightOpacity)
                : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: highlighted
                  ? AppTypography.body.copyWith(
                      color: AppColors.accentPrimary.withValues(alpha: highlightOpacity),
                      fontWeight: FontWeight.w600,
                    )
                  : AppTypography.body,
            ),
          ),
          if (highlighted)
            Icon(
              Icons.touch_app,
              size: 18,
              color: AppColors.accentPrimary.withValues(alpha: highlightOpacity),
            )
          else
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.accentPrimaryMuted,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: AppTypography.label.copyWith(color: AppColors.accentPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: AppTypography.body)),
      ],
    );
  }
}