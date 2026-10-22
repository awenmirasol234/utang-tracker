import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/features/notifications/domain/entities/debt_notification.dart';
import 'package:utang_tracker/features/notifications/presentation/providers/notification_providers.dart';

Future<String?> showDebtNotificationsSheet(BuildContext context) {
  return showAppModalBottomSheet<String>(
    context: context,
    builder: (_) => const _DebtNotificationsSheet(),
  );
}

class _DebtNotificationsSheet extends ConsumerWidget {
  const _DebtNotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(debtNotificationsProvider);

    return AppModalBottomSheet(
      title: 'Due reminders',
      subtitle: 'Due now and soon.',
      trailing: IconButton(
        tooltip: 'Close reminders',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
      child: notifications.when(
        loading: () => const LoadingIndicator(message: 'Checking due dates'),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(debtNotificationsProvider.notifier).refresh(),
        ),
        data: (feed) => _NotificationLedger(feed: feed),
      ),
    );
  }
}

class _NotificationLedger extends StatelessWidget {
  const _NotificationLedger({required this.feed});

  final DebtNotificationFeed feed;

  @override
  Widget build(BuildContext context) {
    if (feed.isEmpty) {
      return const _EmptyNotifications();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.lg,
        AppSpacing.pagePadding,
        AppSpacing.xxl,
      ),
      children: [
        _AttentionSummary(feed: feed),
        const SizedBox(height: AppSpacing.xl),
        for (final kind in DebtNotificationKind.values) ...[
          if (feed.byKind(kind).isNotEmpty) ...[
            _NotificationSection(kind: kind, items: feed.byKind(kind)),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ],
    );
  }
}

class _AttentionSummary extends StatelessWidget {
  const _AttentionSummary({required this.feed});

  final DebtNotificationFeed feed;

  @override
  Widget build(BuildContext context) {
    final urgent = feed.urgentCount;
    Color backgroundColor;
    Color iconColor;
    IconData icon;
    String message;
    if (urgent > 0) {
      backgroundColor = AppColors.unpaidBg;
      iconColor = AppColors.unpaid;
      icon = Icons.notification_important_outlined;
      message = '$urgent due now';
    } else {
      backgroundColor = AppColors.primaryLight;
      iconColor = AppColors.primaryDark;
      icon = Icons.event_available_outlined;
      message = '${feed.items.length} due soon';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({required this.kind, required this.items});

  final DebtNotificationKind kind;
  final List<DebtNotification> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _sectionLabel(kind),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: _foreground(kind)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _background(kind),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${items.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _foreground(kind),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border.all(color: AppColors.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _NotificationRow(notification: items[index]),
                if (index != items.length - 1)
                  const Divider(indent: 64, endIndent: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});

  final DebtNotification notification;

  @override
  Widget build(BuildContext context) {
    final kind = notification.kind;
    final timingLabel = _timingLabel(notification);
    final dueDateLabel = context.smartDate(notification.dueDate);
    String dateDescription;
    if (timingLabel == dueDateLabel) {
      dateDescription = dueDateLabel;
    } else {
      dateDescription = '$timingLabel · $dueDateLabel';
    }
    return InkWell(
      onTap: () => Navigator.pop(context, notification.debt.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _background(kind),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(kind), size: 19, color: _foreground(kind)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.debt.customerName ?? 'Customer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _foreground(kind),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            MoneyText(notification.debt.balance),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 24,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No reminders',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'No due debts.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

String _sectionLabel(DebtNotificationKind kind) => switch (kind) {
  DebtNotificationKind.overdue => 'OVERDUE',
  DebtNotificationKind.dueToday => 'DUE TODAY',
  DebtNotificationKind.dueSoon => 'COMING UP',
};

String _timingLabel(DebtNotification notification) {
  switch (notification.kind) {
    case DebtNotificationKind.overdue:
      return '${notification.daysFromToday.abs()}d late';
    case DebtNotificationKind.dueToday:
      return 'Today';
    case DebtNotificationKind.dueSoon:
      if (notification.daysFromToday == 1) return 'Tomorrow';
      return 'In ${notification.daysFromToday}d';
  }
}

IconData _icon(DebtNotificationKind kind) => switch (kind) {
  DebtNotificationKind.overdue => Icons.warning_amber_rounded,
  DebtNotificationKind.dueToday => Icons.today_outlined,
  DebtNotificationKind.dueSoon => Icons.event_outlined,
};

Color _foreground(DebtNotificationKind kind) => switch (kind) {
  DebtNotificationKind.overdue => AppColors.unpaid,
  DebtNotificationKind.dueToday => AppColors.partial,
  DebtNotificationKind.dueSoon => AppColors.primaryDark,
};

Color _background(DebtNotificationKind kind) => switch (kind) {
  DebtNotificationKind.overdue => AppColors.unpaidBg,
  DebtNotificationKind.dueToday => AppColors.partialBg,
  DebtNotificationKind.dueSoon => AppColors.primaryLight,
};
