// lib/widgets/pack_selector.dart
//
// Segmented control for choosing the active icon pack — 3 equal segments,
// deliberately NOT a dropdown (§2, Icon pack selector).

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PackSelector extends StatelessWidget {
  const PackSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelBuilder,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final String Function(String id) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadius.smRadius,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: options.map((id) {
          final isSelected = id == selected;
          return Expanded(
            child: Semantics(
              selected: isSelected,
              button: true,
              label: labelBuilder(id),
              child: GestureDetector(
                onTap: () => onChanged(id),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.fastCurve,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentPrimaryMuted : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labelBuilder(id),
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: isSelected ? AppColors.accentPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}