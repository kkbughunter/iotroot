import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../workspace/data/workspace_models.dart';

class HomeWidgetTopic {
  const HomeWidgetTopic({
    required this.name,
    required this.topic,
    required this.enabled,
  });

  final String name;
  final String topic;
  final bool enabled;

  Map<String, Object> toMap() => {
    'name': name,
    'topic': topic,
    'enabled': enabled,
  };
}

abstract final class HomeWidgetBridge {
  static const _channel = MethodChannel('com.astraval.iotroot/home_widget');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void listenForToggles(
    Future<bool?> Function(String topic, bool enabled)? handler,
  ) {
    if (!supported) return;
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method != 'publishToggle') return false;
              final arguments = Map<Object?, Object?>.from(
                call.arguments as Map,
              );
              final topic = arguments['topic']?.toString() ?? '';
              final enabled = arguments['enabled'] == true;
              if (topic.isEmpty) return false;
              final delivered = await handler(topic, enabled);
              return {
                'handled': delivered != null,
                'delivered': delivered == true,
              };
            },
    );
  }

  static Future<bool> add({
    required Device device,
    required String username,
    required String password,
    required BrokerSettings broker,
    required List<HomeWidgetTopic> topics,
  }) async {
    if (!supported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'addWidget',
        _details(device, username, password, broker, topics),
      );
      return result ?? false;
    } on Object {
      // Native widgets are optional and unavailable in tests/non-Android hosts.
      return false;
    }
  }

  static Future<void> sync({
    required Device device,
    required String username,
    required String password,
    required BrokerSettings broker,
    required List<HomeWidgetTopic> topics,
  }) async {
    if (!supported || topics.isEmpty) return;
    try {
      await _channel.invokeMethod<void>(
        'syncWidgetData',
        _details(device, username, password, broker, topics),
      );
    } on Object {
      // Widget synchronization must never interrupt an MQTT connection.
    }
  }

  static Map<String, Object> _details(
    Device device,
    String username,
    String password,
    BrokerSettings broker,
    List<HomeWidgetTopic> topics,
  ) => {
    'host': broker.host,
    'port': broker.port,
    'tls': broker.tls,
    'clientId': device.clientId,
    'username': username,
    'password': password,
    'topics': topics.map((topic) => topic.toMap()).toList(),
  };

  static Future<void> clearConnection() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('clearConnection');
    } on Object {
      // Logging out must still succeed if native widget storage is unavailable.
    }
  }
}
