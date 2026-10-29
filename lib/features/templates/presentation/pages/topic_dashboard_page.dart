import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../workspace/data/workspace_models.dart';
import '../../../workspace/presentation/workspace_forms.dart';
import '../../domain/entities/iot_template.dart';
import '../controllers/template_controller.dart';

class TopicDashboardPage extends StatelessWidget {
  const TopicDashboardPage({super.key, required this.controller});
  final TemplateController controller;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0EFFA), Color(0xFFF0F6F4), Color(0xFFF8F7F2)],
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 350
            ? 2
            : 1;
        return SingleChildScrollView(
          key: const PageStorageKey<String>('topics'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: controller.showDevices,
                icon: const Icon(Icons.arrow_back),
                label: const Text('All devices'),
              ),
              Text(
                controller.selectedDevice?.name ?? 'Device details',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '${controller.rules.length} topics · ${controller.connected ? "Client connected" : "Connect your client to control devices"}',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: controller.selectedDevice == null
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => WorkspaceForm(
                              controller: controller,
                              device: controller.selectedDevice,
                            ),
                          ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit device'),
                  ),
                  TextButton.icon(
                    onPressed: controller.selectedDevice == null
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => WorkspaceForm(
                              controller: controller,
                              topic: true,
                            ),
                          ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add topic'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (controller.rules.isEmpty &&
                  !controller.loadingRules &&
                  !controller.busy)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No topics yet. Add a topic to this device to get started.',
                    ),
                  ),
                ),
              for (
                var start = 0;
                start < controller.rules.length;
                start += columns
              )
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var offset = 0; offset < columns; offset++) ...[
                        if (offset > 0) const SizedBox(width: 12),
                        Expanded(
                          child: start + offset < controller.rules.length
                              ? _TopicCard(
                                  controller: controller,
                                  rule: controller.rules[start + offset],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.controller, required this.rule});
  final TemplateController controller;
  final TopicRule rule;

  @override
  Widget build(BuildContext context) {
    final template = controller.templateFor(rule);
    final configured = controller.hasTemplate(rule);
    final latest = controller.latestFor(rule);
    final values = controller.controlsFor(rule);
    final name = rule.name;
    return Card(
      key: ValueKey('topic-card:${rule.id}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: () => controller.openTopic(rule),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: configured
                              ? template.color.withValues(alpha: .12)
                              : AppTheme.canvas,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          configured ? template.icon : Icons.widgets_outlined,
                          color: configured ? template.color : AppTheme.muted,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('topic-details:${rule.id}'),
                    tooltip: 'Topic details and script',
                    onPressed: () => controller.openTopic(rule),
                    icon: const Icon(Icons.code_rounded, size: 21),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                rule.topic,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                rule.canPublish
                    ? (configured ? template.name : 'Choose your controls')
                    : 'Read only',
                style: const TextStyle(fontSize: 12, color: AppTheme.green),
              ),
              const SizedBox(height: 10),
              if (latest != null) ...[
                Text(
                  latest.payload,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Last received ${TimeOfDay.fromDateTime(latest.time).format(context)}',
                  style: const TextStyle(fontSize: 10),
                ),
                const SizedBox(height: 8),
              ] else if (rule.canSubscribe) ...[
                const Text('Waiting for data', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
              ],
              if (rule.isStored)
                const Text(
                  'View stored graphs and groups',
                  style: TextStyle(fontSize: 12),
                )
              else if (configured && rule.canPublish) ...[
                for (final control in template.controls) ...[
                  _control(context, control, values[control.id]!),
                  const SizedBox(height: 8),
                ],
                if (rule.wildcard && controller.destinationFor(rule).isEmpty)
                  const Text(
                    'Set an exact topic in details.',
                    style: TextStyle(fontSize: 12),
                  ),
                const Text('Command draft', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: ValueKey('send-topic:${rule.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: controller.canSendTopic(rule)
                        ? () async {
                            final sent = await controller.sendTopicCommand(
                              rule,
                            );
                            if (context.mounted && sent) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Broker acknowledged command for ${controller.destinationFor(rule)}.',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: const Text('Send command'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _control(BuildContext context, TemplateControl control, Object value) {
    final enabled =
        controller.connected && !controller.connecting && !controller.sending;
    void update(Object next) =>
        controller.updateTopicControl(rule, control, next);
    return switch (control.type) {
      ControlType.toggle => Row(
        children: [
          Expanded(
            child: Text(control.label, style: const TextStyle(fontSize: 12)),
          ),
          Switch(value: value as bool, onChanged: enabled ? update : null),
        ],
      ),
      ControlType.range => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${control.label}: ${(value as num).round()}${control.unit}',
            style: const TextStyle(fontSize: 12),
          ),
          Slider(
            value: value.toDouble(),
            min: control.min,
            max: control.max,
            divisions: (control.max - control.min).round().clamp(1, 100),
            onChanged: enabled ? update : null,
          ),
        ],
      ),
      ControlType.options => DropdownButtonFormField<String>(
        key: ValueKey('${rule.id}:$templateId:${control.id}'),
        initialValue: value as String,
        isExpanded: true,
        decoration: InputDecoration(labelText: control.label),
        items: control.options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: enabled
            ? (v) {
                if (v != null) update(v);
              }
            : null,
      ),
      ControlType.action => TextButton(
        onPressed: enabled
            ? () => update(DateTime.now().millisecondsSinceEpoch.toString())
            : null,
        child: Text(control.label),
      ),
    };
  }

  String get templateId => controller.templateFor(rule).id;
}
