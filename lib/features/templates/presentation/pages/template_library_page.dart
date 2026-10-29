import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/iot_template.dart';
import '../controllers/template_controller.dart';
import '../widgets/page_header.dart';
import '../widgets/template_card.dart';

class TemplateLibraryPage extends StatelessWidget {
  const TemplateLibraryPage({super.key, required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey<String>('templates'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: const PageHeader(
                  eyebrow: 'Topic templates',
                  title: 'Choose a template',
                  description: 'Select a device and topic above, then choose its controls and data display. Your choice is saved for each topic.',
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All templates',
                        selected: controller.categoryFilter == null,
                        onTap: () => controller.setCategory(null),
                      ),
                      for (final category in TemplateCategory.values) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: _categoryLabel(category),
                          selected: controller.categoryFilter == category,
                          onTap: () => controller.setCategory(category),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 1030
                  ? 3
                  : width >= 650
                  ? 2
                  : 1;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 250,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final template = controller.filteredTemplates[index];
                  return TemplateCard(
                    template: template,
                    selected: template.id == controller.selectedTemplate.id,
                    onTap: () => controller.selectTemplate(template),
                  );
                }, childCount: controller.filteredTemplates.length),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _categoryLabel(TemplateCategory category) => switch (category) {
    TemplateCategory.home => 'Home',
    TemplateCategory.environment => 'Environment',
    TemplateCategory.safety => 'Safety',
    TemplateCategory.energy => 'Energy',
  };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      showCheckmark: false,
      selectedColor: AppTheme.ink,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppTheme.ink : AppTheme.line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.muted,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
