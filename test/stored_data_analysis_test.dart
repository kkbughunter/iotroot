import 'package:flutter_test/flutter_test.dart';
import 'package:iotroot/features/templates/data/stored_data_analysis.dart';
import 'package:iotroot/features/workspace/data/workspace_models.dart';

void main() {
  test(
      'nested numeric values form chronological series and categories are counted',
      () {
    final analysis = StoredDataAnalysis([
      {
        'receivedAt': '2026-10-29T10:01:00Z',
        'payload': {
          'sensor': {'temperature': 24.5},
          'status': 'on',
          'active': true,
          'missing': null,
          'samples': [1, 2]
        }
      },
      {
        'receivedAt': '2026-10-29T10:00:00Z',
        'payload': {
          'sensor': {'temperature': 21},
          'status': 'off',
          'active': true
        }
      },
    ]);
    expect(analysis.numeric['sensor.temperature']!.map((p) => p.value),
        [21, 24.5]);
    expect(analysis.groups['active'], {'true': 2});
    expect(analysis.groups['status'], {'off': 1, 'on': 1});
    expect(analysis.groups['missing'], {'null': 1});
    expect(analysis.structure['samples'], 'array');
    expect(analysis.numeric.containsKey('samples'), isFalse);
    expect(StoredDataAnalysis([]).structure, isEmpty);
  });
  test('display names fall back without changing MQTT credentials or paths',
      () {
    final device = Device.fromJson({
      'id': 1,
      'clientId': 'client',
      'username': 'mqtt-user',
      'displayName': 'Living room'
    });
    final topic = TopicRule.fromJson({
      'id': 2,
      'topic': '/iot/store/1/temp',
      'topicName': 'Temperature',
      'permission': 'publish',
      'topicType': 'STORE'
    });
    expect(device.name, 'Living room');
    expect(device.username, 'mqtt-user');
    expect(topic.name, 'Temperature');
    expect(topic.topic, '/iot/store/1/temp');
    expect(topic.isStored, isTrue);
    expect(const Device(id: 1, clientId: 'client', username: 'legacy').name,
        'legacy');
    expect(
        const TopicRule(id: 1, topic: 'legacy/path', permission: 'publish')
            .name,
        'legacy/path');
  });
}
