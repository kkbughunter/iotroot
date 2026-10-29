import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/entities/iot_template.dart';
import '../controllers/template_controller.dart';
import '../widgets/command_panel.dart';
import '../widgets/telemetry_chart.dart';
import '../widgets/stored_topic_data.dart';
import '../../../workspace/presentation/workspace_forms.dart';

class LiveTemplatePage extends StatelessWidget {
  const LiveTemplatePage({super.key, required this.controller});
  final TemplateController controller;
  @override
  Widget build(BuildContext context) {
    final template = controller.selectedTemplate;
    final rule = controller.selectedRule;
    if (rule == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Select a device with topic rules to view live data.'),
        ),
      );
    }
    return SingleChildScrollView(
      key: const PageStorageKey<String>('live-template'),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => controller.setPage(0),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('All topics'),
              ),
              Text(
                'Topic details',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                rule.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              SelectableText('${rule.topic} · ${rule.permission}'),
              TextButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => WorkspaceForm(
                    controller: controller,
                    topic: true,
                    rule: rule,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit topic'),
              ),
              const SizedBox(height: 16),
              if (rule.isStored)
                StoredTopicData(
                  key: ValueKey('${controller.selectedDevice?.id}:${rule.id}'),
                  controller: controller,
                )
              else ...[
                Text(
                  'Set up template',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('template:${rule.id}:${template.id}'),
                  initialValue: template.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Template for this topic',
                  ),
                  items: controller.templates
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      controller.selectTemplate(
                        controller.templates.firstWhere((t) => t.id == id),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (!controller.hasTemplate(rule))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton.icon(
                      onPressed: () => controller.selectTemplate(template),
                      icon: const Icon(Icons.check),
                      label: const Text('Use this template'),
                    ),
                  ),
                if (!rule.canSubscribe)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'This topic allows publishing only. Live readings require a subscribe or readwrite rule.',
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final readings = Column(
                      children: [
                        for (final metric in template.metrics) ...[
                          _MetricCard(controller: controller, metric: metric),
                          const SizedBox(height: 12),
                        ],
                        _PayloadCard(controller: controller),
                      ],
                    );
                    final commands = CommandPanel(controller: controller);
                    return constraints.maxWidth < 760
                        ? Column(
                            children: [
                              readings,
                              const SizedBox(height: 16),
                              commands,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: readings),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: commands),
                            ],
                          );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.controller, required this.metric});
  final TemplateController controller;
  final TemplateMetric metric;
  @override
  Widget build(BuildContext context) {
    final value = controller.latestMetricValue(metric);
    final points = controller.metricHistory[metric.id] ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metric.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              value == null
                  ? 'Waiting for data'
                  : '${value.toStringAsFixed(value.abs() >= 100 ? 0 : 1)} ${metric.unit}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (points.isNotEmpty)
              Text(
                'Updated ${points.last.time.toLocal().toString().split('.').first}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 12),
            TelemetryChart(
              points: points,
              color: controller.selectedTemplate.color,
              metric: metric,
            ),
            TextFormField(
              key: ValueKey(
                '${controller.selectedDevice?.id}:${controller.selectedRule?.id}:${controller.selectedTemplate.id}:${metric.id}',
              ),
              initialValue: controller.metricKey(metric),
              decoration: const InputDecoration(
                labelText: 'Payload field',
                helperText: 'Nested path: data.temperature. Leave blank for a numeric payload.',
              ),
              onChanged: (value) => controller.setMetricKey(metric, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.controller});
  final TemplateController controller;
  @override
  Widget build(BuildContext context) {
    final message = controller.latestMessage;
    String payload =
        message?.payload ?? 'No messages received for this topic yet.';
    if (message != null) {
      try {
        payload = const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(payload));
      } on FormatException {
        /* Keep plain text. */
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Latest payload · all fields',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${message.topic}\n${message.time.toLocal()}'),
              ),
            const SizedBox(height: 8),
            SelectableText(
              payload,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
