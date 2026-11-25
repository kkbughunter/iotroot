import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../workspace/data/workspace_models.dart';
import '../controllers/template_controller.dart';
import '../widgets/stored_topic_data.dart';
import '../widgets/thermometer_readings.dart';
import 'control_type_selection_page.dart';

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
                const SizedBox(height: 12),
                _TopicControlCard(controller: controller, rule: rule),
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

class _TopicControlCard extends StatelessWidget {
  const _TopicControlCard({required this.controller, required this.rule});

  final TemplateController controller;
  final TopicRule rule;

  @override
  Widget build(BuildContext context) {
    final type = controller.controlTypeFor(rule);
    final enabled = controller.powerFor(rule);
    final range = controller.fanRangeFor(rule);
    final canSend = controller.canSendTopic(rule);
    final sending = controller.isSendingTopic(rule);
    final isThermometer = type == TopicControlType.thermometer;
    final isRawText = type == TopicControlType.rawText;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose Your Controle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('choose-topic-control'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ControlTypeSelectionPage(
                    controller: controller,
                    rule: rule,
                  ),
                ),
              ),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Choose control layout'),
            ),
            const SizedBox(height: 12),
            if (isRawText)
              _RawTextComposer(controller: controller)
            else if (isThermometer)
              ThermometerReadings(controller: controller, rule: rule)
            else
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  type == TopicControlType.fan ? 'Fan status' : 'Status',
                ),
                subtitle: Text(enabled ? 'On' : 'Off'),
                value: enabled,
                onChanged: canSend
                    ? (value) {
                        if (type == TopicControlType.fan) {
                          controller.sendFanCommand(rule, value, range);
                        } else {
                          controller.setTopicPower(rule, value);
                        }
                      }
                    : null,
              ),
            if (type == TopicControlType.fan) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('Speed')),
                  Text(
                    '$range',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Slider(
                value: range.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$range',
                onChanged: canSend
                    ? (value) => controller.setFanRange(rule, value.round())
                    : null,
              ),
              FilledButton.icon(
                onPressed: canSend
                    ? () => controller.sendFanCommand(rule, enabled, range)
                    : null,
                icon: const Icon(Icons.send_rounded),
                label: Text(sending ? 'Sending…' : 'Send fan command'),
              ),
            ],
            if (!isThermometer && !isRawText && sending) ...[
              const SizedBox(height: 8),
              const Text(
                'Waiting for broker acknowledgement…',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ] else if (!isThermometer && !isRawText && !canSend) ...[
              const SizedBox(height: 8),
              const Text(
                'Connect to the broker with publish permission to use this control.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RawTextComposer extends StatefulWidget {
  const _RawTextComposer({required this.controller});

  final TemplateController controller;

  @override
  State<_RawTextComposer> createState() => _RawTextComposerState();
}

class _RawTextComposerState extends State<_RawTextComposer> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await widget.controller.sendRawText(_message.text);
    if (!mounted || !sent) return;
    _message.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        widget.controller.canSend && _message.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('raw-text-message'),
            controller: _message,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => canSend ? _send() : null,
            decoration: const InputDecoration(
              hintText: 'Type a message',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          key: const Key('send-raw-text'),
          tooltip: 'Send message',
          onPressed: canSend ? _send : null,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
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
