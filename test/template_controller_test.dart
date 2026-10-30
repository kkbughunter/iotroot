import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iotroot/features/templates/data/template_repository.dart';
import 'package:iotroot/features/templates/domain/entities/iot_template.dart';
import 'package:iotroot/features/templates/presentation/controllers/template_controller.dart';
import 'package:iotroot/features/workspace/data/workspace_models.dart';

import 'support/fakes.dart';

void main() {
  late TemplateController controller;
  late FakeBroker broker;
  late MemoryStore store;
  setUp(() async {
    store = MemoryStore();
    broker = FakeBroker();
    controller = TemplateController(
      TemplateRepository(),
      api: fixtureApi(store: store),
      broker: broker,
    );
    await controller.initialize();
    await controller.login('https://example.com', 'user@example.com', 'secret');
  });
  tearDown(() => controller.dispose());

  test('loads every available client and the selected client rules', () {
    expect(controller.devices.length, 2);
    expect(controller.selectedDevice!.clientId, 'client-one');
    expect(controller.rules.length, 3);
    expect(controller.events, isEmpty);
    expect(
      controller.latestMetricValue(controller.selectedTemplate.metrics.first),
      isNull,
    );
    expect(controller.brokerSettings.host, 'localhost');
  });
  test('topic templates persist separately and nested metrics preserve real values', () async {
    final climate = controller.templates.firstWhere((t) => t.id == 'climate');
    controller.selectTemplate(climate);
    controller.setMetricKey(climate.metrics.first, 'data.temp');
    broker.receive('room/climate', '{"data":{"temp":125},"extra":null}');
    expect(controller.latestMetricValue(climate.metrics.first), 125);
    expect((controller.events.first.payload as Map)['extra'], isNull);
    controller.selectRule(controller.rules[1]);
    controller.selectTemplate(
      controller.templates.firstWhere((t) => t.id == 'smart-fan'),
    );
    expect(controller.latestMessage, isNull);
    controller.selectRule(controller.rules.first);
    expect(controller.selectedTemplate.id, 'climate');
    expect(controller.metricKey(climate.metrics.first), 'data.temp');
    expect(controller.latestMetricValue(climate.metrics.first), 125);
    await Future<void>.delayed(Duration.zero);
    await controller.loadWorkspace();
    expect(controller.selectedTemplate.id, 'climate');
    expect(controller.latestMessage, isNull);
  });
  test('connect uses API device identity; publish is acknowledged on exact ACL topic', () async {
    await controller.connect('mqtt-secret', controller.brokerSettings);
    expect(broker.device!.clientId, 'client-one');
    expect(broker.password, 'mqtt-secret');
    expect(await controller.sendCommand(), isTrue);
    expect(broker.published.keys, ['room/climate']);
    expect(controller.events.single.direction, EventDirection.sent);
    broker.failPublish = true;
    expect(await controller.sendCommand(), isFalse);
    expect(controller.events.length, 1);
    controller.selectRule(controller.rules[1]);
    expect(controller.canSend, isFalse);
    controller.selectRule(controller.rules[2]);
    expect(controller.canSend, isFalse);
    controller.setPublishTopic('elsewhere/topic');
    expect(controller.canSend, isFalse);
    controller.setPublishTopic('commands/light');
    expect(controller.canSend, isTrue);
  });
  test(
    'the app device is the one whose username matches the account email',
    () async {
      final emailStore = MemoryStore();
      final emailController = TemplateController(
        TemplateRepository(),
        api: fixtureApi(store: emailStore, secondUsername: 'user@example.com'),
        broker: FakeBroker(),
      );
      addTearDown(emailController.dispose);
      await emailController.initialize();
      await emailController.login(
        'https://example.com',
        'User@Example.com',
        'secret',
      );
      expect(emailController.devices, hasLength(2));
      expect(emailController.selectedDevice!.id, 2);
    },
  );
  test('logout disconnects and clears previous data', () async {
    await controller.connect('mqtt-secret', controller.brokerSettings);
    broker.receive('room/climate', '42');
    expect(controller.latestMessage, isNotNull);
    await controller.logout();
    expect(controller.connected, isFalse);
    expect(controller.authenticated, isFalse);
    expect(controller.events, isEmpty);
    expect(controller.devices, isEmpty);
    expect(controller.metricHistory.values.every((p) => p.isEmpty), isTrue);
  });
  test(
    'restores the app device, edited username and password on restart',
    () async {
      expect(controller.needsClientSetup, isTrue);
      expect(
        await controller.connect(
          'saved-secret',
          controller.brokerSettings,
          username: 'updated-user',
        ),
        isTrue,
      );
      final restoredBroker = FakeBroker();
      final restored = TemplateController(
        TemplateRepository(),
        api: fixtureApi(store: store),
        broker: restoredBroker,
      );
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.devices, hasLength(2));
      expect(restored.selectedDevice!.id, 1);
      expect(restored.connected, isTrue);
      expect(restored.needsClientSetup, isFalse);
      expect(restoredBroker.connects, 1);
      expect(restoredBroker.device!.clientId, 'client-one');
      expect(restoredBroker.device!.username, 'updated-user');
      expect(restoredBroker.password, 'saved-secret');
      expect(restoredBroker.settings!.host, 'localhost');
    },
  );

  test('forgetting credentials stops automatic reconnection', () async {
    await controller.connect('secret', controller.brokerSettings);
    await controller.connect(
      'new-secret',
      controller.brokerSettings,
      remember: false,
    );
    expect(await controller.savedPassword(), isNull);
    final restoredBroker = FakeBroker();
    final restored = TemplateController(
      TemplateRepository(),
      api: fixtureApi(store: store),
      broker: restoredBroker,
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restoredBroker.connects, 0);
    expect(restored.needsClientSetup, isTrue);
  });

  test('failed credentials do not overwrite the saved password', () async {
    await controller.connect('working-secret', controller.brokerSettings);
    broker.failConnect = true;
    expect(
      await controller.connect('bad-secret', controller.brokerSettings),
      isFalse,
    );
    expect(await controller.savedPassword(), 'working-secret');
    expect(controller.error, contains('Invalid credentials'));
  });

  test('topic cards keep independent drafts and publish without changing selection', () async {
    final first = controller.rules.first;
    final other = controller.rules.last;
    final light = controller.templates.first;
    controller.selectTemplate(light);
    controller.updateControl(light.controls.first, true);
    controller.selectRule(other);
    controller.selectTemplate(light);
    controller.setPublishTopic('commands/light');
    controller.updateTopicControl(other, light.controls[1], 25.0);
    await controller.connect('secret', controller.brokerSettings);
    expect(await controller.sendTopicCommand(first), isTrue);
    expect(controller.selectedRule, other);
    expect(jsonDecode(broker.published['room/climate']!)['command'], 'on');
    expect(await controller.sendTopicCommand(other), isTrue);
    expect(jsonDecode(broker.published['commands/light']!)['brightness'], 25);
    expect(jsonDecode(broker.published['commands/light']!)['command'], 'off');
    controller.selectRule(first);
    expect(controller.controlValues['power'], isTrue);
    expect(controller.controlValues['brightness'], 70.0);
    expect(await controller.sendTopicCommand(controller.rules[1]), isFalse);
  });

  test(
    'topic control type is saved and fan publishes status and range',
    () async {
      final rule = controller.rules.first;
      await controller.setTopicControlType(rule, TopicControlType.fan);
      controller.setFanRange(rule, 7);
      await controller.connect('secret', controller.brokerSettings);

      expect(controller.controlTypeFor(rule), TopicControlType.fan);
      expect(controller.fanRangeFor(rule), 7);
      expect(await controller.sendFanCommand(rule, true, 7), isTrue);
      expect(jsonDecode(broker.published['room/climate']!), {
        'status': 'on',
        'range': 7,
      });
      expect(broker.retained['room/climate'], isTrue);
    },
  );

  test('MQTT state initializes standard topic controls', () async {
    final rule = controller.rules.first;
    await controller.setTopicControlType(rule, TopicControlType.fan);
    await controller.connect('secret', controller.brokerSettings);

    broker.receive('room/climate', '{"status":"on","range":8}');

    expect(controller.powerFor(rule), isTrue);
    expect(controller.fanRangeFor(rule), 8);
  });

  test('MQTT filters follow level boundaries, wildcards and system topics', () {
    expect(matchesTopic('room/#', 'room'), isTrue);
    expect(matchesTopic('room/+', 'room/temp'), isTrue);
    expect(matchesTopic('room/+', 'room/temp/value'), isFalse);
    expect(matchesTopic('#', r'$SYS/status'), isFalse);
    expect(matchesTopic(r'$SYS/#', r'$SYS/status'), isTrue);
    expect(matchesTopic('room/#', 'room/+'), isFalse);
    expect(matchesTopic('room/#', 'room\x00'), isFalse);
  });
}
