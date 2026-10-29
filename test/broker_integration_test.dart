import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotroot/features/workspace/data/broker_service.dart';
import 'package:iotroot/features/workspace/data/workspace_models.dart';

void main() {
  final executable = Platform.environment['MQTT_TEST_BROKER'];
  test(
      'authenticated MQTT connects, subscribes, receives UTF-8 and acknowledges QoS 1',
      () async {
    final temp = await Directory.systemTemp.createTemp('iotroot-mqtt-test-');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final passwordFile = '${temp.path}/passwords';
    final passwordTool =
        Platform.environment['MQTT_TEST_PASSWORD_TOOL'] ?? 'mosquitto_passwd';
    final result = await Process.run(passwordTool,
        ['-c', '-b', passwordFile, 'test-device', 'test-only-secret']);
    expect(result.exitCode, 0);
    final config = File('${temp.path}/broker.conf');
    await config.writeAsString(
        'listener $port 127.0.0.1\nallow_anonymous false\npassword_file $passwordFile\npersistence false\n');
    final process = await Process.start(executable!, ['-c', config.path]);
    final out = process.stdout.drain<void>();
    final err = process.stderr.drain<void>();
    final broker = MqttBrokerConnection();
    addTearDown(() async {
      broker.disconnect();
      process.kill();
      await process.exitCode;
      await out;
      await err;
      await temp.delete(recursive: true);
    });
    var ready = false;
    for (var i = 0; i < 40; i++) {
      try {
        final probe = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(milliseconds: 100));
        probe.destroy();
        ready = true;
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    expect(ready, isTrue);
    final received = Completer<BrokerMessage>();
    broker.onMessage = (message) {
      if (!received.isCompleted) received.complete(message);
    };
    final statuses = <String>[];
    broker.onStatus = statuses.add;
    await broker.connect(
      const Device(
          id: 1,
          clientId: 'iotroot-integration-client',
          username: 'test-device'),
      'test-only-secret',
      BrokerSettings(host: '127.0.0.1', port: port),
      [
        const TopicRule(id: 1, topic: 'test/telemetry', permission: 'readwrite')
      ],
    );
    const payload = '{"temperature":25.4,"label":"温度 °C","extra":null}';
    await broker.publish('test/telemetry', payload);
    final message = await received.future.timeout(const Duration(seconds: 5));
    expect(message.topic, 'test/telemetry');
    expect(message.payload, payload);
    expect(statuses, contains('Connected'));
    broker.disconnect();
    await expectLater(broker.publish('test/telemetry', '{}'), throwsStateError);
    await expectLater(
        broker.connect(
          const Device(
              id: 1,
              clientId: 'iotroot-invalid-client',
              username: 'test-device'),
          'incorrect-password',
          BrokerSettings(host: '127.0.0.1', port: port),
          [],
        ),
        throwsStateError);
  },
      skip: executable == null
          ? 'Set MQTT_TEST_BROKER to the mosquitto executable to run the local broker test.'
          : false);
}
