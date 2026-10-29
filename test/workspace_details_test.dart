import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:iotroot/core/api_client.dart';
import 'package:iotroot/features/templates/data/template_repository.dart';
import 'package:iotroot/features/templates/presentation/controllers/template_controller.dart';
import 'package:iotroot/features/templates/presentation/pages/live_template_page.dart';
import 'package:iotroot/features/templates/presentation/widgets/telemetry_chart.dart';
import 'package:iotroot/features/workspace/data/workspace_models.dart';
import 'package:iotroot/features/workspace/presentation/workspace_forms.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'editing names preserves credentials and sends only the topic suffix',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return reply(tokens);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          writes.add(body);
          return reply(
            request.url.path.contains('/rules/')
                ? {...body, 'id': 2, 'topic': '/iot/store/1/${body['topic']}'}
                : {...body, 'id': 1, 'clientId': 'client'},
          );
        }),
      );
      await api.login('https://example.com', 'user@example.com', 'secret');
      final controller = TemplateController(
        TemplateRepository(),
        api: api,
        broker: FakeBroker(),
      );
      addTearDown(controller.dispose);
      const device = Device(
        id: 1,
        clientId: 'client',
        username: 'mqtt-user',
        displayName: 'Old device',
      );
      controller.devices = [device];
      controller.selectedDevice = device;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      WorkspaceForm(controller: controller, device: device),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Device name'),
        '  Living room  ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes.single['displayName'], 'Living room');
      expect(writes.single['username'], 'mqtt-user');
      expect(writes.single.containsKey('password'), isFalse);
      expect(controller.selectedDevice!.name, 'Living room');

      const rule = TopicRule(
        id: 2,
        topic: '/iot/store/1/+/temperature',
        topicName: 'Old topic',
        permission: 'publish',
        topicType: 'STORE',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceForm(
              controller: controller,
              topic: true,
              rule: rule,
            ),
          ),
        ),
      );
      expect(find.text('+/temperature'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Topic name'),
        ' Temperature ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(writes.last['topicName'], 'Temperature');
      expect(writes.last['topic'], '+/temperature');
      expect(writes.last['topicType'], 'STORE');
      expect(controller.rules.single.name, 'Temperature');
    },
  );

  testWidgets(
    'stored wildcard history filters messages and renders graphs without a template or broker',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, String>>[];
      final api = ApiClient(
        store: MemoryStore(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return reply(tokens);
          queries.add(request.url.queryParameters);
          return reply({
            'content': [
              {
                'id': 1,
                'topic': '/iot/store/1/a/status',
                'receivedAt': '2026-10-29T10:01:00Z',
                'payload': {
                  'sensor': {'temperature': 24},
                  'state': 'on',
                },
              },
              {
                'id': 2,
                'topic': '/iot/store/1/a/other',
                'receivedAt': '2026-10-29T10:00:00Z',
                'payload': {'temperature': 99},
              },
            ],
            'totalElements': 2,
            'totalPages': 1,
          });
        }),
      );
      await api.login('https://example.com', 'user@example.com', 'secret');
      final controller = TemplateController(
        TemplateRepository(),
        api: api,
        broker: FakeBroker(),
      );
      addTearDown(controller.dispose);
      controller.selectedDevice = const Device(
        id: 1,
        clientId: 'client',
        username: 'mqtt',
      );
      controller.selectedRule = const TopicRule(
        id: 2,
        topic: '/iot/store/1/+/status',
        permission: 'publish',
        topicType: 'STORE',
      );
      controller.pageIndex = 1;
      await controller.loadHistory();
      expect(queries.single['topicPrefix'], '/iot/store/1/');
      expect(queries.single.containsKey('topic'), isFalse);
      expect(
        DateTime.parse(queries.single['to']!)
            .difference(DateTime.parse(queries.single['from']!)),
        const Duration(hours: 1),
      );
      expect(controller.storedMessages.length, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (_, _) => LiveTemplatePage(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set up template'), findsNothing);
      expect(find.byType(TelemetryChart), findsOneWidget);
      expect(find.text('sensor.temperature'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Pie chart of 1 groups across 1 values'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(queries.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
