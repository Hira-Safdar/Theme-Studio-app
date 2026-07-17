// lib/widgets/icon_list_row.dart
//
// Icon list row — 44×44 icon slot, name + package (secondary), gallery-pick
// icon-button, Apply button. States: default, custom-picked (pencil badge),
// applying, applied, failed (row tints error, label becomes "retry"). §2.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum IconRowStatus { idle, applying, applied, failed }

class IconListRow extends StatelessWidget {
  const IconListRow({
    super.key,
    required this.label,
    required this.packageName,
    required this.status,
    required this.hasCustomIcon,
    required this.previewPath,
    required this.previewIsFile,
    required this.canEditIcon,
    required this.isSelected,
    required this.oldIconBytes,
    required this.onToggleSelected,
    required this.onPickCustomIcon,
    required this.onApply,
  });

  final String label;
  final String packageName;
  final IconRowStatus status;
  final bool hasCustomIcon;
  final String previewPath;
  final bool previewIsFile;
  final bool canEditIcon;
  final bool isSelected;
  final Uint8List? oldIconBytes;
  final ValueChanged<bool?> onToggleSelected;
  final VoidCallback onPickCustomIcon;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final isFailed = status == IconRowStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isFailed
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.bgSurface,
        borderRadius: AppRadius.mdRadius,
        border: isFailed ? Border.all(color: AppColors.error) : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: onToggleSelected,
            activeColor: AppColors.accentPrimary,
          ),
          _IconTransitionGroup(
            oldIconBytes: oldIconBytes,
            newIconPath: previewPath,
            newIconIsFile: previewIsFile,
            hasCustomIcon: hasCustomIcon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.body),
                const SizedBox(height: 2),
                Text(packageName, style: AppTypography.bodySecondary),
              ],
            ),
          ),
          // Bundled packs (Cartoon/Flat colors/Dark mode) fixed/curated hain
          // -- edit sirf "Custom" tab par allowed hai, isliye ye button
          // sirf tab dikhta hai jab canEditIcon true ho.
          if (canEditIcon)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: 'Pick custom icon for $label',
              color: AppColors.textSecondary,
              onPressed: status == IconRowStatus.applying ? null : onPickCustomIcon,
            ),
          _ApplyButton(status: status, onPressed: onApply),
        ],
      ),
    );
  }
}

/// "Before -> after" preview group: asal device icon (Kotlin se fetch kiya
/// hua), phir arrow, phir naya icon-pack/custom preview -- reference design
/// (Themie-style icon changer) ke row layout se match karne ke liye.
class _IconTransitionGroup extends StatelessWidget {
  const _IconTransitionGroup({
    required this.oldIconBytes,
    required this.newIconPath,
    required this.newIconIsFile,
    required this.hasCustomIcon,
  });

  final Uint8List? oldIconBytes;
  final String newIconPath;
  final bool newIconIsFile;
  final bool hasCustomIcon;

  Widget _buildFallback() =>
      const Icon(Icons.android, color: AppColors.textSecondary, size: 22);

  Widget _oldIconWidget() {
    if (oldIconBytes == null) return _buildFallback();
    return Image.memory(
      oldIconBytes!,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _newIconWidget() {
    if (newIconPath.isEmpty) return _buildFallback();
    if (newIconIsFile) {
      return Image.file(
        File(newIconPath),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }
    return Image.asset(
      newIconPath,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _iconBox(Widget child) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceRaised,
          borderRadius: AppRadius.mdRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBox(_oldIconWidget()),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            _iconBox(_newIconWidget()),
          ],
        ),
        if (hasCustomIcon)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 10, color: Color(0xFF00201E)),
            ),
          ),
      ],
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.status, required this.onPressed});
  final IconRowStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (status == IconRowStatus.applying) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.accentPrimary),
          ),
        ),
      );
    }

    if (status == IconRowStatus.applied) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Icon(Icons.check_circle, color: AppColors.success),
      );
    }

    final isFailed = status == IconRowStatus.failed;
    return FilledButton(
      onPressed: onPressed,
      style: isFailed
          ? FilledButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              foregroundColor: AppColors.error,
            )
          : null,
      child: Text(isFailed ? 'Retry' : 'Apply'),
    );
  }
}