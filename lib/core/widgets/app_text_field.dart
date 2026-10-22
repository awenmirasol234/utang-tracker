import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.enabled = true,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.style,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextStyle? style;
  final FocusNode? focusNode;

  static Widget buildLabel(
    BuildContext context,
    String label, {
    TextStyle? style,
  }) {
    final baseStyle =
        style ??
        Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary);

    if (!label.contains('*')) {
      return Text(label, style: baseStyle);
    }

    final children = <InlineSpan>[];
    final parts = label.split('*');
    for (var index = 0; index < parts.length; index++) {
      if (parts[index].isNotEmpty) {
        children.add(TextSpan(text: parts[index]));
      }
      if (index < parts.length - 1) {
        children.add(
          const TextSpan(
            text: '*',
            style: TextStyle(color: AppColors.danger),
          ),
        );
      }
    }

    return Text.rich(TextSpan(style: baseStyle, children: children));
  }

  static TextStyle? inputStyle(BuildContext context, {Color? color}) {
    return Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w500);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          buildLabel(context, label!),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: style ?? inputStyle(context),
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          inputFormatters: inputFormatters,
          enabled: enabled,
          autofocus: autofocus,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
