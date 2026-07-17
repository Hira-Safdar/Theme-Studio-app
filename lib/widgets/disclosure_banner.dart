// lib/widgets/disclosure_banner.dart
//
// Single persistent strip under the app bar (not per-row), neutral tone,
// used wherever Android — not the app — owns the final confirmation
// (Icon Changer, Widget pin, Accessibility card). Never worded as an
// apology ("unfortunately," "due to limitations"). §2 + §3.4.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DisclosureBanner extends StatelessWidget {
  const DisclosureBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.bgSurface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppTypography.bodySecondary),
          ),
        ],
      ),
    );
  }
}