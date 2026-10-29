import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotroot/app/iot_root_app.dart';
import 'package:iotroot/features/templates/data/template_repository.dart';
import 'package:iotroot/features/templates/presentation/controllers/template_controller.dart';
import 'support/fakes.dart';

void main() {
  for (final width in [360.0, 390.0, 1200.0]) {
    testWidgets(
        'login, topic template, live payload and activity fit width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final broker = FakeBroker();
      final controller = TemplateController(TemplateRepository(),
          api: fixtureApi(), broker: broker);
      await tester.pumpWidget(IotRootApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to IoTRoot'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Client setup'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Broker host'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Broker port'), findsNothing);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Client password'), 'mqtt-secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
      await tester.pumpAndSettle();
      expect(find.text('All devices'), findsNothing);
      expect(find.text('Add topic'), findsNothing);
      expect(find.text('Set up template'), findsNothing);
      expect(find.byKey(const ValueKey('topic-card:11')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-card:12')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-card:13')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('topic-card:11')));
      await tester.pumpAndSettle();
      expect(find.text('Topic details'), findsWidgets);
      await tester.tap(find.text('Use this template'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await controller.connect('mqtt-secret', controller.brokerSettings);
      broker.receive('room/climate', '{"power_draw":8.4,"extra":"real"}');
      await tester.pumpAndSettle();
      expect(find.text('8.4 W'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('send-command')));
      await tester.tap(find.byKey(const Key('send-command')));
      await tester.pumpAndSettle();
      expect(broker.published.keys, contains('room/climate'));
      await tester.tap(find.text('My home').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('topic-card:11')), findsOneWidget);
      expect(find.byKey(const ValueKey('send-topic:11')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Activity').last);
      await tester.pumpAndSettle();
      expect(controller.pageIndex, 2);
      expect(controller.events.length, 2);
      await tester.drag(find.byKey(const PageStorageKey<String>('activity')),
          const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(find.text('SENT'), findsOneWidget);
      expect(find.text('RECEIVED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to IoTRoot'), findsOneWidget);
    });
  }
  testWidgets(
      'saved client reconnects without setup and settings allow credential updates',
      (tester) async {
    final store = MemoryStore();
    final seed = TemplateController(TemplateRepository(),
        api: fixtureApi(store: store), broker: FakeBroker());
    await seed.initialize();
    await seed.login('https://example.com', 'user@example.com', 'secret');
    await seed.connect('saved-password', seed.brokerSettings);
    seed.dispose();
    final broker = FakeBroker();
    final controller = TemplateController(TemplateRepository(),
        api: fixtureApi(store: store), broker: broker);
    await tester.pumpWidget(IotRootApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Client setup'), findsNothing);
    expect(broker.connects, 1);
    expect(broker.password, 'saved-password');
    await tester.tap(find.byTooltip('Client settings'));
    await tester.pumpAndSettle();
    expect(find.text('Client setup'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'edited-user');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Client password'),
        'edited-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Client setup'), findsNothing);
    expect(broker.device!.username, 'edited-user');
    expect(await controller.savedPassword(), 'edited-password');
    expect(tester.takeException(), isNull);
  });
}
