import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../workspace/data/workspace_models.dart';
import '../controllers/template_controller.dart';
import '../widgets/stored_topic_data.dart';

class TopicDetailsPage extends StatelessWidget {
  const TopicDetailsPage({super.key, required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rule = controller.selectedRule;
        return Scaffold(
          appBar: AppBar(title: const Text('Topic details')),
          body: rule == null
              ? const Center(child: Text('Topic not found.'))
              : _TopicDetailsBody(controller: controller, rule: rule),
        );
      },
    );
  }
}

class _TopicDetailsBody extends StatelessWidget {
  const _TopicDetailsBody({required this.controller, required this.rule});

  final TemplateController controller;
  final TopicRule rule;

  String get _permission => switch (rule.permission) {
    'publish' => 'Publish',
    'subscribe' => 'Subscribe',
    'readwrite' => 'Publish & subscribe',
    _ => rule.permission,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0EFFA), Color(0xFFF0F6F4), Color(0xFFF8F7F2)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          rule.topic,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Divider(height: 28),
                        Wrap(
                          spacing: 28,
                          runSpacing: 14,
                          children: [
                            _Detail(label: 'Permission', value: _permission),
                            _Detail(
                              label: 'Type',
                              value: rule.isStored ? 'Stored' : 'Standard',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (rule.isStored) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: StoredTopicData(controller: controller),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
