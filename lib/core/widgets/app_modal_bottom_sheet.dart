import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    showDragHandle: true,
    builder: builder,
  );
}

class AppModalBottomSheet extends StatelessWidget {
  const AppModalBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.headerBottom,
    this.footer,
    this.heightFactor = 0.75,
  }) : assert(heightFactor > 0 && heightFactor <= 1);

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? headerBottom;
  final Widget child;
  final Widget? footer;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    CrossAxisAlignment titleAlignment;
    if (subtitle == null) {
      titleAlignment = CrossAxisAlignment.center;
    } else {
      titleAlignment = CrossAxisAlignment.start;
    }

    return SizedBox(
      key: const Key('app-modal-bottom-sheet'),
      height: MediaQuery.sizeOf(context).height * heightFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              0,
              AppSpacing.pagePadding,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: titleAlignment,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      trailing!,
                    ],
                  ],
                ),
                if (headerBottom != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  headerBottom!,
                ],
              ],
            ),
          ),
          Expanded(
            child: ListTileTheme.merge(
              titleTextStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              subtitleTextStyle: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              leadingAndTrailingTextStyle: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              child: child,
            ),
          ),
          if (footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  AppSpacing.sm,
                  AppSpacing.pagePadding,
                  AppSpacing.md,
                ),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}
