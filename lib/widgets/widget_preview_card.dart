// lib/widgets/widget_preview_card.dart
//
// Widget preview card — live-rendered widget preview (not a screenshot
// placeholder), outlined "Pin to Home Screen" button (outlined signals a
// system-dialog action, matching the disclosure pattern used once at the
// top of the screen rather than repeated per card). §2 + §3.5.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum WidgetPinStatus { idle, requesting, pinned }

class WidgetPreviewCard extends StatelessWidget {
  const WidgetPreviewCard({
    super.key,
    required this.name,
    required this.preview,
    required this.status,
    required this.onPin,
    required this.onRetry,
  });

  final String name;
  final Widget preview;
  final WidgetPinStatus status;
  final VoidCallback onPin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppElevation.level1(radius: AppRadius.lgRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: preview),
          const SizedBox(height: AppSpacing.md),
          Text(name, style: AppTypography.heading),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: _buildAction(),
          ),
        ],
      ),
    );
  }

  Widget _buildAction() {
    switch (status) {
      case WidgetPinStatus.idle:
        return OutlinedButton(
          onPressed: onPin,
          child: const Text('Pin to Home Screen'),
        );

      case WidgetPinStatus.requesting:
        return const OutlinedButton(
          onPressed: null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.textSecondary),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text('Waiting for confirmation…'),
            ],
          ),
        );

      case WidgetPinStatus.pinned:
        return Column(
          children: [
            const OutlinedButton(
              onPressed: null,
              child: Text('Pinned'),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                "Didn't see it? Try again",
                style: AppTypography.bodySecondary,
              ),
            ),
          ],
        );
    }
  }
}