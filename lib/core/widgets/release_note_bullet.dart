import 'package:flutter/material.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';

class ReleaseNoteBullet extends StatelessWidget {
  const ReleaseNoteBullet(this.note, {super.key});

  final String note;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: 1.6,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: style),
        Expanded(child: Text(note, style: style)),
      ],
    );
  }
}
