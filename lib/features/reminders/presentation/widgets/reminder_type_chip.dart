import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReminderTypeChip extends StatelessWidget {
  const ReminderTypeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.24),
      side: BorderSide(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.50)
            : AppColors.glassBorder,
      ),
    );
  }
}
