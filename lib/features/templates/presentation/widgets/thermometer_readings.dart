import 'package:flutter/material.dart';

import '../../../workspace/data/workspace_models.dart';
import '../controllers/template_controller.dart';

class ThermometerReadings extends StatelessWidget {
  const ThermometerReadings({
    super.key,
    required this.controller,
    required this.rule,
    this.compact = false,
  });

  final TemplateController controller;
  final TopicRule rule;
  final bool compact;

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final temperature = controller.thermometerValueFor(rule, 'temperature');
    final humidity = controller.thermometerValueFor(rule, 'humidity');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Reading(
          icon: Icons.thermostat_rounded,
          label: compact ? 'Temp' : 'Temperature',
          value: '${_format(temperature)} °C',
          compact: compact,
        ),
        SizedBox(height: compact ? 4 : 10),
        _Reading(
          icon: Icons.water_drop_outlined,
          label: 'Humidity',
          value: '${_format(humidity)}%',
          compact: compact,
        ),
      ],
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.icon,
    required this.label,
    required this.value,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: compact ? 15 : 22, color: const Color(0xFF287A6B)),
      SizedBox(width: compact ? 5 : 9),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10 : 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Text(
        value,
        key: ValueKey('thermometer:${ruleKey(label)}'),
        style: TextStyle(
          fontSize: compact ? 18 : 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  String ruleKey(String value) => value.toLowerCase();
}
