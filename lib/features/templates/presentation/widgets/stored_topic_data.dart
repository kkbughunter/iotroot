import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../data/stored_data_analysis.dart';
import '../../domain/entities/iot_template.dart';
import '../controllers/template_controller.dart';
import 'telemetry_chart.dart';

class StoredTopicData extends StatefulWidget {
  const StoredTopicData({super.key, required this.controller});
  final TemplateController controller;
  @override
  State<StoredTopicData> createState() => _StoredTopicDataState();
}

class _StoredTopicDataState extends State<StoredTopicData>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final controller = widget.controller;
      if (_foreground && controller.selectedRule?.isStored == true) {
        unawaited(controller.loadHistory());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final rows = controller.storedMessages;
    final analysis = StoredDataAnalysis(rows);
    final latest = rows.firstOrNull;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Stored data', style: theme.textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.loadingHistory
                  ? null
                  : controller.loadHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Last 30 minutes · topic view includes messages from every device.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.hub_outlined),
              label: Text('All devices'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.memory_rounded),
              label: Text('This device'),
            ),
          ],
          selected: {controller.storedDeviceOnly},
          onSelectionChanged: controller.loadingHistory
              ? null
              : (values) => controller.setStoredDeviceOnly(values.first),
        ),
        if (controller.loadingHistory) const LinearProgressIndicator(),
        if (controller.historyError != null)
          Text(
            controller.historyError!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (latest == null &&
            !controller.loadingHistory &&
            controller.historyError == null)
          const Text('No messages in the last 30 minutes.'),
        if (latest != null) ...[
          _section(
            theme,
            'Latest message',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_deviceName(controller, latest)} · ${_time(latest['receivedAt'])} · ${latest['topic']}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 6),
                _JsonBox(payload: latest['payload']),
              ],
            ),
          ),
          for (final series in analysis.numeric.entries.take(8))
            _section(
              theme,
              series.key,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${series.value.last.value} · ${series.value.length} samples',
                    style: const TextStyle(fontSize: 12),
                  ),
                  TelemetryChart(
                    points: series.value,
                    color: AppTheme.green,
                    metric: TemplateMetric(
                      id: series.key,
                      label: series.key,
                      unit: '',
                      min: series.value.map((p) => p.value).reduce(math.min),
                      max: series.value.map((p) => p.value).reduce(math.max),
                    ),
                  ),
                ],
              ),
            ),
          for (final group in analysis.groups.entries.take(8))
            _section(theme, group.key, _GroupedBars(counts: group.value)),
          if (analysis.numeric.isEmpty && analysis.groups.isEmpty)
            const Text('No numeric, text or boolean fields to chart.'),
          if (analysis.structure.isNotEmpty)
            _section(
              theme,
              'Fields',
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final field in analysis.structure.entries)
                    Text(
                      '${field.key} (${field.value})',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          _section(
            theme,
            'Recent messages',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${_deviceName(controller, row)} · ${_time(row['receivedAt'])}  ${jsonEncode(row['payload'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (controller.hasMoreHistory)
            TextButton(
              onPressed: controller.loadingHistory
                  ? null
                  : () => controller.loadHistory(more: true),
              child: const Text('Load more'),
            ),
        ],
      ],
    );
  }

  String _time(Object? value) =>
      DateTime.tryParse('$value')?.toLocal().toString().split('.').first ??
      '$value';

  String _deviceName(TemplateController controller, Map<String, dynamic> row) {
    final id = (row['deviceId'] as num?)?.toInt();
    return controller.devices
            .where((device) => device.id == id)
            .firstOrNull
            ?.name ??
        row['clientId']?.toString() ??
        'Device #${id ?? '?'}';
  }

  Widget _section(ThemeData theme, String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 24),
      Text(title, style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _JsonBox extends StatelessWidget {
  const _JsonBox({required this.payload});
  final Object? payload;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 240),
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppTheme.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SingleChildScrollView(
      child: SelectableText(
        const JsonEncoder.withIndent('  ').convert(payload),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ),
  );
}

class _GroupedBars extends StatelessWidget {
  const _GroupedBars({required this.counts});
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final maximum = top.first.value;
    return Column(
      children: [
        for (final item in top)
          Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  item.key.isEmpty ? '(empty)' : item.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(value: item.value / maximum),
              ),
              const SizedBox(width: 8),
              Text('${item.value}', style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}
