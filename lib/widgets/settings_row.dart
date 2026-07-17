// lib/widgets/settings_row.dart
//
// Shared row anatomy for Settings (§3.7): bg.surface background per group
// (grouped card, radius.md, rows separated by 1px border.subtle hairlines,
// not individual floating cards), icon (20px, text.secondary) + label
// (type.body) + trailing chevron or toggle. Standard row height ~52px.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps a list of [SettingsRow]s in the grouped-card look with hairline
/// separators between rows, per §3.7's row anatomy.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: AppSpacing.xxxl, thickness: 1),
          ],
        ],
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
        top: AppSpacing.lg,
      ),
      child: Text(label, style: AppTypography.label),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailingText,
    this.onTap,
    this.toggleValue,
    this.onToggleChanged,
  });

  final IconData icon;
  final String label;

  /// e.g. a version string shown right-aligned with no chevron.
  final String? trailingText;

  /// Chevron-row tap target. Omit for a direct-toggle row or a
  /// non-interactive row (e.g. Version).
  final VoidCallback? onTap;

  /// If set, renders a trailing Switch instead of a chevron.
  final bool? toggleValue;
  final ValueChanged<bool>? onToggleChanged;

  bool get _isToggleRow => toggleValue != null;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isToggleRow ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTypography.body)),
            if (_isToggleRow)
              Switch(value: toggleValue!, onChanged: onToggleChanged)
            else if (trailingText != null)
              Text(trailingText!, style: AppTypography.bodySecondary)
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}