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
      if (_foreground &&
          controller.pageIndex == 1 &&
          controller.selectedRule?.isStored == true) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Stored topic data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh stored messages',
              onPressed:
                  controller.loadingHistory ? null : controller.loadHistory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text('Last hour · refreshes every 10 seconds'),
        Text('${rows.length} matching messages loaded'),
        if (controller.loadingHistory) const LinearProgressIndicator(),
        if (controller.historyError != null)
          Text(
            controller.historyError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        if (latest == null &&
            !controller.loadingHistory &&
            controller.historyError == null)
          const Text('No stored messages for this topic in the last hour.'),
        if (latest != null)
          _section(
            context,
            'Latest message',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_time(latest['receivedAt'])),
                SelectableText('${latest['topic']}'),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ')
                          .convert(latest['payload']),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final series in analysis.numeric.entries.take(8))
          _section(
            context,
            series.key,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${series.value.last.value} · ${series.value.length} numeric samples',
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
          _section(context, group.key, _GroupedPie(counts: group.value)),
        if (rows.isNotEmpty &&
            analysis.numeric.isEmpty &&
            analysis.groups.isEmpty)
          const Text(
            'These payloads contain no chartable numeric, text or boolean fields.',
          ),
        if (analysis.structure.isNotEmpty)
          _section(
            context,
            'Latest payload structure',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in analysis.structure.entries)
                  Chip(
                    label: Text(
                      '${field.key} · ${field.value}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        if (rows.isNotEmpty)
          _section(
            context,
            'Recent messages',
            Column(
              children: [
                for (final row in rows.take(200))
                  ExpansionTile(
                    title: Text(
                      _time(row['receivedAt']),
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${row['topic']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(row['payload']),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        if (controller.hasMoreHistory)
          TextButton(
            onPressed: controller.loadingHistory
                ? null
                : () => controller.loadHistory(more: true),
            child: const Text('Load more messages from this hour'),
          ),
      ],
    );
  }

  String _time(Object? value) =>
      DateTime.tryParse('$value')?.toLocal().toString().split('.').first ??
      '$value';
  Widget _section(BuildContext context, String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

const _colors = [
  Color(0xFF147D5A),
  Color(0xFF8390FA),
  Color(0xFFF0AC45),
  Color(0xFF348ACA),
  Color(0xFFE47777),
  Color(0xFF9667BA),
  Color(0xFF37AAA4),
  Color(0xFF89919B),
];

class _GroupedPie extends StatelessWidget {
  const _GroupedPie({required this.counts});
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final entries = sorted.take(7).toList();
    if (sorted.length > 7) {
      entries.add(
        MapEntry(
          'Other values',
          sorted.skip(7).fold(0, (sum, item) => sum + item.value),
        ),
      );
    }
    final total = entries.fold(0, (sum, item) => sum + item.value);
    return Column(
      children: [
        Semantics(
          label: 'Pie chart of ${counts.length} groups across $total values',
          child: SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _PiePainter(entries.map((e) => e.value).toList()),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(width: 10, height: 10, color: _colors[i]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entries[i].key.isEmpty ? '(empty string)' : entries[i].key,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  '${entries[i].value} · ${(entries[i].value / total * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.counts);
  final List<int> counts;
  @override
  void paint(Canvas canvas, Size size) {
    final total = counts.fold(0, (sum, count) => sum + count);
    if (total == 0) return;
    var angle = -math.pi / 2;
    for (var i = 0; i < counts.length; i++) {
      final sweep = counts[i] / total * 2 * math.pi;
      canvas.drawArc(
        Offset.zero & size,
        angle,
        sweep,
        true,
        Paint()..color = _colors[i],
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => true;
}
