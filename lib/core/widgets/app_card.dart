import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.margin,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    ShapeBorder? cardShape;
    if (borderColor != null) {
      cardShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor!),
      );
    }
    Clip? clipBehavior;
    Widget cardChild;
    if (onTap == null) {
      cardChild = Padding(padding: padding, child: child);
    } else {
      clipBehavior = Clip.antiAlias;
      cardChild = InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      );
    }

    return Card(
      margin: margin ?? EdgeInsets.zero,
      color: color,
      shape: cardShape,
      clipBehavior: clipBehavior,
      child: cardChild,
    );
  }
}
