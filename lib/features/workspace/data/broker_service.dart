import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'workspace_models.dart';

abstract class BrokerConnection {
  void Function(String status)? onStatus;
  void Function(BrokerMessage message)? onMessage;
  Future<void> connect(
    Device device,
    String password,
    BrokerSettings settings,
    List<TopicRule> rules,
  );
  Future<void> publish(String topic, String payload);
  void disconnect();
}

class MqttBrokerConnection extends BrokerConnection {
  MqttServerClient? _client;
  StreamSubscription? _messages;
  StreamSubscription? _published;
  final Map<int, Completer<void>> _pending = {};
  int _generation = 0;

  @override
  Future<void> connect(
    Device device,
    String password,
    BrokerSettings settings,
    List<TopicRule> rules,
  ) async {
    disconnect();
    final generation = _generation;
    final client = MqttServerClient.withPort(
      settings.host,
      device.clientId,
      settings.port,
    );
    _client = client;
    client
      ..secure = settings.tls
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 10000
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false)
      ..setProtocolV311();
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(device.clientId)
        .startClean();
    bool current() => generation == _generation;
    client.onDisconnected = () {
      if (current()) {
        _failPending();
        onStatus?.call('Disconnected');
      }
    };
    client.onAutoReconnect = () {
      if (current()) {
        _failPending();
        onStatus?.call('Reconnecting');
      }
    };
    client.onAutoReconnected = () {
      if (current()) onStatus?.call('Connected');
    };
    client.onSubscribeFail = (topic) {
      if (current()) onStatus?.call('Subscription rejected: $topic');
    };
    onStatus?.call('Connecting');
    try {
      await client.connect(device.username, password);
      if (!current()) {
        client.disconnect();
        return;
      }
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('Broker rejected connection');
      }
      _messages = client.updates?.listen((batch) {
        if (!current()) return;
        for (final item in batch) {
          final message = item.payload as MqttPublishMessage;
          onMessage?.call(
            BrokerMessage(
              item.topic,
              utf8.decode(message.payload.message, allowMalformed: true),
              DateTime.now(),
            ),
          );
        }
      });
      _published = client.published?.listen((message) {
        _pending.remove(message.variableHeader?.messageIdentifier)?.complete();
      });
      onStatus?.call('Connected');
      for (final topic
          in rules.where((r) => r.canSubscribe).map((r) => r.topic).toSet()) {
        client.subscribe(topic, MqttQos.atLeastOnce);
      }
    } catch (_) {
      if (current()) {
        disconnect();
        onStatus?.call('Connection failed');
      }
      throw StateError(
        'Cannot connect. Check the client username and MQTT password, then try again. If this continues, check your connection or contact your administrator.',
      );
    }
  }

  @override
  Future<void> publish(String topic, String payload) async {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      throw StateError('Connect to the broker before publishing.');
    }
    final builder = MqttClientPayloadBuilder()..addUTF8String(payload);
    final id = client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: false,
    );
    final completer = Completer<void>();
    _pending[id] = completer;
    try {
      await completer.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw StateError(
        'No broker acknowledgement received. Delivery is unconfirmed.',
      );
    } finally {
      _pending.remove(id);
    }
  }

  void _failPending() {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(
          StateError('Connection lost. Delivery is unconfirmed.'),
        );
      }
    }
    _pending.clear();
  }

  @override
  void disconnect() {
    _generation++;
    _messages?.cancel();
    _published?.cancel();
    _messages = null;
    _published = null;
    _failPending();
    _client?.autoReconnect = false;
    _client?.disconnect();
    _client = null;
  }
}
