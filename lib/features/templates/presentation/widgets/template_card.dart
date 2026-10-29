import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/iot_template.dart';

class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.selected,
    required this.onTap,
  });

  final IotTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? template.color : AppTheme.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: template.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(template.icon, color: template.color, size: 27),
                  ),
                  const Spacer(),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F4EC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.green,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 7),
              Text(
                template.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.sensors_rounded,
                    size: 17,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${template.controls.length} commands  •  ${template.metrics.length} signals',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: AppTheme.ink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
