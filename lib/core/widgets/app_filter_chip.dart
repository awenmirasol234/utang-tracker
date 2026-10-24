import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    Color labelColor;
    Color borderColor;
    double elevation;
    if (selected) {
      labelColor = AppColors.textOnPrimary;
      borderColor = AppColors.primaryDark;
      elevation = 1;
    } else {
      labelColor = AppColors.textPrimary;
      borderColor = AppColors.outline;
      elevation = 0;
    }

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.primaryDark,
      elevation: elevation,
      pressElevation: 2,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: labelColor,
      ),
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
