import 'package:flutter/material.dart';

import '../domain/entities/iot_template.dart';

class TemplateRepository {
  List<IotTemplate> getAll() => const <IotTemplate>[
    IotTemplate(
      id: 'smart-light',
      name: 'Smart light',
      description: 'Switch a light on or off and set its brightness.',
      category: TemplateCategory.home,
      icon: Icons.lightbulb_outline_rounded,
      color: Color(0xFFF4A621),
      controls: <TemplateControl>[
        TemplateControl(
          id: 'power',
          label: 'Light power',
          jsonKey: 'command',
          type: ControlType.toggle,
          defaultValue: false,
        ),
        TemplateControl(
          id: 'brightness',
          label: 'Brightness',
          jsonKey: 'brightness',
          type: ControlType.range,
          defaultValue: 70.0,
          unit: '%',
        ),
      ],
      metrics: <TemplateMetric>[
        TemplateMetric(
          id: 'power_draw',
          label: 'Power draw',
          unit: 'W',
          min: 0,
          max: 12,
        ),
      ],
    ),
    IotTemplate(
      id: 'smart-fan',
      name: 'Smart fan',
      description: 'Control fan power and choose a speed from 1 to 6.',
      category: TemplateCategory.home,
      icon: Icons.mode_fan_off_outlined,
      color: Color(0xFF4586D6),
      controls: <TemplateControl>[
        TemplateControl(
          id: 'power',
          label: 'Fan power',
          jsonKey: 'status',
          type: ControlType.toggle,
          defaultValue: true,
        ),
        TemplateControl(
          id: 'speed',
          label: 'Fan speed',
          jsonKey: 'speed',
          type: ControlType.range,
          defaultValue: 3.0,
          min: 1,
          max: 6,
        ),
      ],
      metrics: <TemplateMetric>[
        TemplateMetric(
          id: 'rpm',
          label: 'Fan speed',
          unit: 'rpm',
          min: 0,
          max: 1500,
        ),
      ],
    ),
    IotTemplate(
      id: 'climate',
      name: 'Room climate',
      description: 'Monitor temperature and humidity sensor readings.',
      category: TemplateCategory.environment,
      icon: Icons.thermostat_rounded,
      color: Color(0xFFE66C4F),
      controls: <TemplateControl>[
        TemplateControl(
          id: 'interval',
          label: 'Read interval',
          jsonKey: 'interval_sec',
          type: ControlType.options,
          defaultValue: '5 sec',
          options: <String>['1 sec', '5 sec', '10 sec'],
        ),
      ],
      metrics: <TemplateMetric>[
        TemplateMetric(
          id: 'temperature',
          label: 'Temperature',
          unit: '°C',
          min: 16,
          max: 36,
        ),
        TemplateMetric(
          id: 'humidity',
          label: 'Humidity',
          unit: '%',
          min: 30,
          max: 90,
        ),
      ],
    ),
    IotTemplate(
      id: 'water-tank',
      name: 'Water tank',
      description: 'Track water level and test an automatic pump.',
      category: TemplateCategory.environment,
      icon: Icons.water_drop_outlined,
      color: Color(0xFF1B9BA5),
      controls: <TemplateControl>[
        TemplateControl(
          id: 'pump',
          label: 'Water pump',
          jsonKey: 'pump',
          type: ControlType.toggle,
          defaultValue: false,
        ),
        TemplateControl(
          id: 'threshold',
          label: 'Auto-fill threshold',
          jsonKey: 'threshold',
          type: ControlType.range,
          defaultValue: 30.0,
          min: 10,
          max: 90,
          unit: '%',
        ),
      ],
      metrics: <TemplateMetric>[
        TemplateMetric(
          id: 'water_level',
          label: 'Water level',
          unit: '%',
          min: 0,
          max: 100,
        ),
      ],
    ),
    IotTemplate(
      id: 'door-sensor',
      name: 'Door sensor',
      description: 'Receive open/closed events and arm an alert.',
      category: TemplateCategory.safety,
      icon: Icons.door_front_door_outlined,
      color: Color(0xFF8C67C5),
      controls: <TemplateControl>[
        TemplateControl(
          id: 'armed',
          label: 'Alert mode',
          jsonKey: 'armed',
          type: ControlType.toggle,
          defaultValue: true,
        ),
        TemplateControl(
          id: 'test',
          label: 'Test sensor event',
          jsonKey: 'test',
          type: ControlType.action,
          defaultValue: 'trigger',
        ),
      ],
      metrics: <TemplateMetric>[
        TemplateMetric(
          id: 'events',
          label: 'Events',
          unit: '/hr',
          min: 0,
          max: 10,
        ),
      ],
    ),
    IotTemplate(
      id: 'energy-meter',
      name: 'Energy meter',
      description: 'Observe power usage and set a consumption limit.',
      category: TemplateCategory.energy,
      icon: Icons.bolt_rounded,
      color: Color(0xFFDB8A32),
      controls: <TemplateControl>[
        TemplateControl(
          id: 'limit',
          label: 'Usage alert',
          jsonKey: 'limit_watts',
          type: ControlType.range,
          defaultValue: 1800.0,
          min: 500,
          max: 3000,
          unit: 'W',
        ),
      ],
      metrics: <TemplateMetric>[
        TemplateMetric(
          id: 'consumption',
          label: 'Consumption',
          unit: 'W',
          min: 0,
          max: 3000,
        ),
      ],
    ),
  ];
}
