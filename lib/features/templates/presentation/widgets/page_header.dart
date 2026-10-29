import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              Text(title, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 20), trailing!],
      ],
    );
  }
}
