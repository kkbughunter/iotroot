import 'package:flutter/material.dart';

enum TemplateCategory { home, environment, safety, energy }

enum ControlType { toggle, range, options, action }

class TemplateControl {
  const TemplateControl({
    required this.id,
    required this.label,
    required this.jsonKey,
    required this.type,
    required this.defaultValue,
    this.min = 0,
    this.max = 100,
    this.unit = '',
    this.options = const <String>[],
  });

  final String id;
  final String label;
  final String jsonKey;
  final ControlType type;
  final Object defaultValue;
  final double min;
  final double max;
  final String unit;
  final List<String> options;
}

class TemplateMetric {
  const TemplateMetric({
    required this.id,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
  });
  final String id;
  final String label;
  final String unit;
  final double min;
  final double max;
}

class IotTemplate {
  const IotTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.controls,
    required this.metrics,
  });
  final String id;
  final String name;
  final String description;
  final TemplateCategory category;
  final IconData icon;
  final Color color;
  final List<TemplateControl> controls;
  final List<TemplateMetric> metrics;
}

class TelemetryPoint {
  const TelemetryPoint(this.time, this.value);
  final DateTime time;
  final double value;
}

enum EventDirection { sent, received }

class TemplateEvent {
  const TemplateEvent({
    required this.direction,
    required this.templateName,
    required this.topic,
    required this.payload,
    required this.time,
  });
  final EventDirection direction;
  final String templateName;
  final String topic;
  final Object? payload;
  final DateTime time;
}
