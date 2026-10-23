import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';

class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isFocused = false;
  bool _isHovered = false;
  bool _isPressed = false;

  double get _elevation {
    if (_isPressed) return 0;
    if (_isFocused || _isHovered) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    ShapeBorder? cardShape;
    if (widget.borderColor != null) {
      cardShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.borderColor!),
      );
    }
    Clip? clipBehavior;
    Widget cardChild;
    if (widget.onTap == null) {
      cardChild = Padding(padding: widget.padding, child: widget.child);
    } else {
      clipBehavior = Clip.antiAlias;
      cardChild = InkWell(
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onHighlightChanged: (highlighted) =>
            setState(() => _isPressed = highlighted),
        onHover: (hovered) => setState(() => _isHovered = hovered),
        child: Padding(padding: widget.padding, child: widget.child),
      );
    }

    if (widget.onTap != null) {
      return Container(
        margin: widget.margin ?? EdgeInsets.zero,
        child: AnimatedPhysicalModel(
          elevation: _elevation,
          color: widget.color ?? AppColors.surfaceCard,
          shadowColor: AppColors.shadow,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    widget.borderColor ?? Theme.of(context).colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(color: AppColors.transparent, child: cardChild),
          ),
        ),
      );
    }

    return Card(
      margin: widget.margin ?? EdgeInsets.zero,
      color: widget.color,
      shape: cardShape,
      clipBehavior: clipBehavior,
      child: cardChild,
    );
  }
}
