import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../workspace/data/workspace_models.dart';
import '../controllers/template_controller.dart';
import '../widgets/thermometer_readings.dart';

class ControlTypeSelectionPage extends StatefulWidget {
  const ControlTypeSelectionPage({
    super.key,
    required this.controller,
    required this.rule,
  });

  final TemplateController controller;
  final TopicRule rule;

  @override
  State<ControlTypeSelectionPage> createState() =>
      _ControlTypeSelectionPageState();
}

class _ControlTypeSelectionPageState extends State<ControlTypeSelectionPage> {
  late TopicControlType _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.controller.controlTypeFor(widget.rule);
  }

  Future<void> _select(TopicControlType type) async {
    if (_saving) return;
    setState(() {
      _selected = type;
      _saving = true;
    });
    await widget.controller.setTopicControlType(widget.rule, type);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose control layout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tap a card layout to apply it and return.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            for (final type in TopicControlType.values) ...[
              _ControlPreviewCard(
                controller: widget.controller,
                rule: widget.rule,
                type: type,
                selected: _selected == type,
                enabled: !_saving,
                onTap: () => _select(type),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ControlPreviewCard extends StatelessWidget {
  const _ControlPreviewCard({
    required this.controller,
    required this.rule,
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TemplateController controller;
  final TopicRule rule;
  final TopicControlType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  String get _label => switch (type) {
    TopicControlType.switchControl => 'Light / switch',
    TopicControlType.fan => 'Fan',
    TopicControlType.thermometer => 'Thermometer',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: ValueKey('control-preview:${type.name}'),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? colors.primary : colors.outline,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HomeCardPreview(controller: controller, rule: rule, type: type),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCardPreview extends StatelessWidget {
  const _HomeCardPreview({
    required this.controller,
    required this.rule,
    required this.type,
  });

  final TemplateController controller;
  final TopicRule rule;
  final TopicControlType type;

  String? get _latest {
    if (rule.isStored) {
      final row = controller.latestStoredFor(rule);
      return row == null ? null : jsonEncode(row['payload']);
    }
    return controller.latestFor(rule)?.payload;
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    final power = controller.powerFor(rule);
    final range = controller.fanRangeFor(rule);
    final isFan = type == TopicControlType.fan;
    final isThermometer = type == TopicControlType.thermometer;
    final accent = isThermometer
        ? const Color(0xFFDDF2F0)
        : rule.isStored
        ? const Color(0xFFDDF3E5)
        : const Color(0xFFFFE8CC);
    final accentStrong = isThermometer
        ? const Color(0xFF287A6B)
        : rule.isStored
        ? const Color(0xFF287A4B)
        : const Color(0xFFAD5B00);

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: isFan ? double.infinity : 220,
        height: 140,
        child: Card(
          margin: EdgeInsets.zero,
          color: accent,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        isThermometer
                            ? Icons.thermostat_rounded
                            : isFan
                            ? Icons.mode_fan_off_rounded
                            : Icons.lightbulb_outline_rounded,
                        size: 17,
                        color: accentStrong,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (!isThermometer && !isFan)
                  Expanded(
                    child: Center(
                      child: Text(
                        latest ?? 'No data',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: latest == null ? AppTheme.muted : AppTheme.ink,
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (isThermometer)
                  ThermometerReadings(
                    controller: controller,
                    rule: rule,
                    compact: true,
                  )
                else if (isFan)
                  Row(
                    children: [
                      Expanded(
                        child: IgnorePointer(
                          child: Slider(
                            value: range.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$range',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _PreviewSwitch(value: power),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PreviewSwitch(value: power),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewSwitch extends StatelessWidget {
  const _PreviewSwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: .78,
    child: IgnorePointer(
      child: Switch.adaptive(value: value, onChanged: (_) {}),
    ),
  );
}
