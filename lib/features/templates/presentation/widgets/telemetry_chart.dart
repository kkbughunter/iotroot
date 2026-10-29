import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/iot_template.dart';

class TelemetryChart extends StatelessWidget {
  const TelemetryChart({
    super.key,
    required this.points,
    required this.color,
    required this.metric,
  });

  final List<TelemetryPoint> points;
  final Color color;
  final TemplateMetric metric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _ChartPainter(points: points, color: color, metric: metric),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.points,
    required this.color,
    required this.metric,
  });
  final List<TelemetryPoint> points;
  final Color color;
  final TemplateMetric metric;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const bottom = 24.0;
    final chart = Rect.fromLTRB(left, 10, size.width - 4, size.height - bottom);
    final gridPaint = Paint()..color = AppTheme.line;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    final low = points.fold<double>(
      metric.min,
      (value, p) => math.min(value, p.value),
    );
    final high = points.fold<double>(
      metric.max,
      (value, p) => math.max(value, p.value),
    );
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final value = high - ((high - low) * i / 4);
      labelPainter.text = TextSpan(
        text: _number(value),
        style: const TextStyle(color: AppTheme.muted, fontSize: 10),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
          chart.left - labelPainter.width - 8,
          y - labelPainter.height / 2,
        ),
      );
    }

    if (points.isEmpty) return;
    final path = Path();
    final fillPath = Path();
    final span = math.max(high - low, 1);
    for (var i = 0; i < points.length; i++) {
      final elapsed = points.last.time
          .difference(points.first.time)
          .inMilliseconds;
      final x = points.length == 1 || elapsed == 0
          ? chart.center.dx
          : chart.left +
                chart.width *
                    points[i].time
                        .difference(points.first.time)
                        .inMilliseconds /
                    elapsed;
      final ratio = ((points[i].value - low) / span).clamp(0.0, 1.0);
      final y = chart.bottom - chart.height * ratio;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chart.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(chart.right, chart.bottom);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .24), color.withValues(alpha: .01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chart),
    );
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
    final metricPath = path.computeMetrics().lastOrNull;
    final last = points.length == 1
        ? Offset(
            chart.center.dx,
            chart.bottom -
                chart.height *
                    ((points.first.value - low) / span).clamp(0.0, 1.0),
          )
        : metricPath?.getTangentForOffset(metricPath.length)?.position;
    if (last != null) {
      canvas.drawCircle(last, 5, Paint()..color = Colors.white);
      canvas.drawCircle(last, 3.5, Paint()..color = color);
    }

    labelPainter.text = TextSpan(
      text: _time(points.first.time),
      style: TextStyle(color: AppTheme.muted, fontSize: 10),
    );
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(chart.left, chart.bottom + 8));
    labelPainter.text = TextSpan(
      text: _time(points.last.time),
      style: TextStyle(color: AppTheme.muted, fontSize: 10),
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(chart.right - labelPainter.width, chart.bottom + 8),
    );
  }

  String _time(DateTime value) =>
      value.toLocal().toString().split(' ').last.split('.').first;

  String _number(double value) =>
      value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
