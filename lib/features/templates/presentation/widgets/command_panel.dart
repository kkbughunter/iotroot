import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/iot_template.dart';
import '../controllers/template_controller.dart';

class CommandPanel extends StatelessWidget {
  const CommandPanel({super.key, required this.controller});

  final TemplateController controller;

  @override
  Widget build(BuildContext context) {
    final template = controller.selectedTemplate;
    final rule = controller.selectedRule;
    final sending = rule != null && controller.isSendingTopic(rule);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a command',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            const Text('Change the fields and publish the prepared payload.'),
            const SizedBox(height: 16),
            if (controller.selectedRule?.canPublish != true)
              const Text('This topic is read-only. Publishing is disabled.')
            else if (controller.selectedRule!.wildcard)
              TextFormField(
                key: ValueKey(
                  'publish:${controller.selectedDevice?.id}:${controller.selectedRule?.id}',
                ),
                initialValue: controller.publishTopic,
                decoration: const InputDecoration(
                  labelText: 'Exact publish topic',
                  helperText:
                      'Enter a topic matching the selected permission filter.',
                ),
                onChanged: controller.setPublishTopic,
              )
            else
              SelectableText('Publish to: ${controller.publishTopic}'),
            const SizedBox(height: 24),
            for (final control in template.controls) ...[
              _ControlField(controller: controller, control: control),
              const SizedBox(height: 20),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF18251F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAYLOAD PREVIEW',
                    style: TextStyle(
                      color: Color(0xFF87A096),
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    const JsonEncoder.withIndent('  ')
                        .convert(controller.commandPayload),
                    style: const TextStyle(
                      color: Color(0xFFB9EBD7),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('send-command'),
                onPressed: !controller.canSend
                    ? null
                    : () async {
                        final sent = await controller.sendCommand();
                        if (!context.mounted || !sent) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Broker acknowledged the command. Device execution is not confirmed.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  sending ? 'Waiting for acknowledgement…' : 'Send command',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _RawCommand(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _RawCommand extends StatefulWidget {
  const _RawCommand({required this.controller});
  final TemplateController controller;
  @override
  State<_RawCommand> createState() => _RawCommandState();
}

class _RawCommandState extends State<_RawCommand> {
  final _payload = TextEditingController();
  @override
  void dispose() {
    _payload.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Custom payload'),
    tilePadding: EdgeInsets.zero,
    children: [
      TextField(
        controller: _payload,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'JSON or plain text'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: !widget.controller.canSend
            ? null
            : () async {
                final sent = await widget.controller.sendCommand(
                  rawPayload: _payload.text,
                );
                if (sent && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Broker acknowledged the custom payload.'),
                    ),
                  );
                }
              },
        child: const Text('Publish custom payload'),
      ),
    ],
  );
}

class _ControlField extends StatelessWidget {
  const _ControlField({required this.controller, required this.control});
  final TemplateController controller;
  final TemplateControl control;

  @override
  Widget build(BuildContext context) {
    final value = controller.controlValues[control.id]!;
    return switch (control.type) {
      ControlType.toggle => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  control.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text((value as bool) ? 'Command: on' : 'Command: off'),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (next) => controller.updateControl(control, next),
          ),
        ],
      ),
      ControlType.range => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  control.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(value as double).round()}${control.unit}',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: control.min,
            max: control.max,
            divisions: (control.max - control.min).round().clamp(1, 100),
            onChanged: (next) => controller.updateControl(control, next),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${control.min.round()}${control.unit}',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                '${control.max.round()}${control.unit}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      ControlType.options => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(control.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: control.options
                .map(
                  (option) =>
                      ButtonSegment<String>(value: option, label: Text(option)),
                )
                .toList(),
            selected: <String>{value as String},
            onSelectionChanged: (values) =>
                controller.updateControl(control, values.first),
            showSelectedIcon: false,
          ),
        ],
      ),
      ControlType.action => OutlinedButton.icon(
        onPressed: () => controller.updateControl(
          control,
          DateTime.now().millisecondsSinceEpoch.toString(),
        ),
        icon: const Icon(Icons.sensors_rounded),
        label: Text(control.label),
      ),
    };
  }
}
