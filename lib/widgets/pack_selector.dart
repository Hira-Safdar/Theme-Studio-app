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
        color: AppTheme.surface(context),
        borderRadius: AppRadius.smRadius,
        border: Border.all(color: AppTheme.borderSubtle(context)),
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
                    color: isSelected ? AppTheme.accentPrimaryMuted(context) : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labelBuilder(id),
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: isSelected ? AppTheme.accentPrimary(context) : AppTheme.textSecondary(context),
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