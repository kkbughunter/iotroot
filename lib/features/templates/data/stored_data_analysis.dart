import '../domain/entities/iot_template.dart';

class StoredDataAnalysis {
  StoredDataAnalysis(List<Map<String, dynamic>> messages) {
    for (final message in messages.reversed) {
      final time = DateTime.tryParse('${message['receivedAt']}');
      for (final field in flattenPayload(message['payload']).entries) {
        final value = field.value;
        if (value is num && value.isFinite && time != null) {
          numeric
              .putIfAbsent(field.key, () => [])
              .add(TelemetryPoint(time, value.toDouble()));
        } else if (value == null || value is String || value is bool) {
          final counts = groups.putIfAbsent(field.key, () => {});
          final label = value == null ? 'null' : value.toString();
          counts[label] = (counts[label] ?? 0) + 1;
        }
      }
    }
    for (final points in numeric.values) {
      points.sort((a, b) => a.time.compareTo(b.time));
    }
    if (messages.isNotEmpty) {
      structure.addAll(
        flattenPayload(messages.first['payload']).map(
          (key, value) => MapEntry(
            key,
            value == null
                ? 'null'
                : value is bool
                ? 'boolean'
                : value is num
                ? 'number'
                : value is List
                ? 'array'
                : 'string',
          ),
        ),
      );
    }
  }
  final numeric = <String, List<TelemetryPoint>>{};
  final groups = <String, Map<String, int>>{};
  final structure = <String, String>{};
}

Map<String, Object?> flattenPayload(Object? payload) {
  final fields = <String, Object?>{};
  void visit(Object? value, String path) {
    if (value is Map) {
      for (final entry in value.entries) {
        visit(
          entry.value,
          path.isEmpty ? '${entry.key}' : '$path.${entry.key}',
        );
      }
    } else {
      fields[path.isEmpty ? r'$' : path] = value;
    }
  }

  visit(payload, '');
  return fields;
}
