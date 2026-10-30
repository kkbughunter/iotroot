import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iotroot/core/api_client.dart';
import 'package:iotroot/core/secure_store.dart';
import 'package:iotroot/features/workspace/data/broker_service.dart';
import 'package:iotroot/features/workspace/data/workspace_models.dart';

class MemoryStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

http.Response reply(Object? data, {int status = 200, String message = 'OK'}) =>
    http.Response(
      jsonEncode({'status': status < 400, 'data': data, 'message': message}),
      status,
      headers: {'content-type': 'application/json'},
    );
const tokens = {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'expiresInSeconds': 3600,
};

ApiClient fixtureApi({
  MemoryStore? store,
  String secondUsername = 'device-two',
}) => ApiClient(
  store: store ?? MemoryStore(),
  client: MockClient((request) async {
    switch (request.url.path) {
      case '/api/auth/login':
      case '/api/auth/refresh-token':
        return reply(tokens);
      case '/api/auth/logout':
        return reply(null);
      case '/api/devices':
        return reply([
          {
            'id': 1,
            'clientId': 'client-one',
            'username': 'device-one',
            'mountpoint': '',
          },
          {
            'id': 2,
            'clientId': 'client-two',
            'username': secondUsername,
            'mountpoint': '',
          },
        ]);
      case '/api/devices/connection-status':
        return reply([
          {
            'deviceId': 1,
            'brokerHost': 'localhost',
            'brokerPort': 1883,
            'connected': false,
          },
          {
            'deviceId': 2,
            'brokerHost': 'localhost',
            'brokerPort': 1883,
            'connected': true,
          },
        ]);
      case '/api/devices/1/rules':
        return reply([
          {'id': 11, 'topic': 'room/climate', 'permission': 'readwrite'},
          {'id': 12, 'topic': 'room/fan', 'permission': 'subscribe'},
          {'id': 13, 'topic': 'commands/#', 'permission': 'publish'},
        ]);
      case '/api/devices/2/rules':
        return reply([
          {'id': 21, 'topic': 'room/climate', 'permission': 'readwrite'},
        ]);
      default:
        return reply(null, status: 404);
    }
  }),
);

class FakeBroker extends BrokerConnection {
  Device? device;
  String? password;
  bool failPublish = false, failConnect = false;
  int connects = 0;
  BrokerSettings? settings;
  int disconnects = 0;
  final published = <String, String>{};
  @override
  Future<void> connect(
    Device device,
    String password,
    BrokerSettings settings,
    List<TopicRule> rules,
  ) async {
    connects++;
    this.settings = settings;
    if (failConnect) throw StateError('Invalid credentials');
    this.device = device;
    this.password = password;
    onStatus?.call('Connected');
  }

  @override
  Future<void> publish(String topic, String payload) async {
    if (failPublish) throw StateError('Broker unavailable');
    published[topic] = payload;
  }

  @override
  void disconnect() {
    disconnects++;
    device = null;
  }

  void receive(String topic, String payload) =>
      onMessage?.call(BrokerMessage(topic, payload, DateTime.now()));
}
