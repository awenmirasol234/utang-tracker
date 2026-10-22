import 'package:flutter/material.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final DebtStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      DebtStatus.unpaid => (AppColors.unpaidBg, AppColors.unpaid),
      DebtStatus.partial => (AppColors.partialBg, AppColors.partial),
      DebtStatus.paid => (AppColors.paidBg, AppColors.paid),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
