import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:iotroot/core/api_client.dart';
import 'package:iotroot/features/templates/data/template_repository.dart';
import 'package:iotroot/features/templates/presentation/controllers/template_controller.dart';
import 'package:iotroot/features/workspace/data/workspace_models.dart';

import 'support/fakes.dart';

void main() {
  test('stored pages retain a fixed date range and discard results after a topic switch', () async {
    final delayed = Completer<void>();
    final started = Completer<void>();
    final queries = <Map<String, String>>[];
    var historyCalls = 0;
    final api = ApiClient(
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) return reply(tokens);
        if (request.url.path == '/api/store/messages') {
          queries.add(request.url.queryParameters);
          historyCalls++;
          if (historyCalls == 3) {
            started.complete();
            await delayed.future;
          }
          final page = int.parse(request.url.queryParameters['page']!);
          return reply({
            'content': [
              {
                'id': page + 1,
                'topic': '/iot/store/1/climate',
                'payload': {'temperature': 20 + page},
              },
            ],
            'totalElements': 2,
            'totalPages': 2,
          });
        }
        return reply([]);
      }),
    );
    await api.login('https://example.com', 'a@b.com', 'secret');
    final controller = TemplateController(
      TemplateRepository(),
      api: api,
      broker: FakeBroker(),
    );
    addTearDown(controller.dispose);
    controller.selectedDevice = const Device(
      id: 1,
      clientId: 'client',
      username: 'device',
    );
    controller.selectedRule = const TopicRule(
      id: 1,
      topic: '/iot/store/1/climate',
      permission: 'readwrite',
      topicType: 'STORE',
    );
    await controller.loadHistory();
    expect(controller.storedMessages.length, 1);
    expect(controller.hasMoreHistory, isTrue);
    await controller.loadHistory(more: true);
    expect(controller.storedMessages.length, 2);
    expect(controller.hasMoreHistory, isFalse);
    expect(queries[0]['to'], queries[1]['to']);
    expect(queries[0]['topic'], '/iot/store/1/climate');
    expect(queries[0].containsKey('deviceId'), isFalse);
    final pending = controller.loadHistory();
    await started.future;
    controller.selectRule(
      const TopicRule(id: 2, topic: 'room/fan', permission: 'subscribe'),
    );
    delayed.complete();
    await pending;
    expect(controller.storedMessages, isEmpty);
    expect(controller.loadingHistory, isFalse);
  });
}
