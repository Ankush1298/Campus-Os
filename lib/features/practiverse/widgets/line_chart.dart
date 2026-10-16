import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChartSeries {
  final String label;
  final List<Offset> points; // real computed data, in data coordinates
  final Color color;
  final bool dashed;
  final bool showPoints;
  const ChartSeries({
    required this.label,
    required this.points,
    required this.color,
    this.dashed = false,
    this.showPoints = false,
  });
}

/// A plain labelled line chart (axes, ticks, grid, optional highlighted point). It plots exactly the points it is given.
class LineChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final double xMax;
  final double yMax;
  final Offset? marker;
  final Color markerColor;

  LineChartPainter({
    required this.series,
    required this.xMax,
    required this.yMax,
    this.marker,
    this.markerColor = const Color(0xFFDC2626),
  });

  static String tick(double v) {
    if (v == 0) return '0';
    if (v.abs() >= 100) return v.toStringAsFixed(0);
    if (v.abs() >= 10) return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0, bottom = 24.0, top = 8.0, right = 10.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    Offset map(Offset p) => Offset(
      plot.left + (p.dx / xMax).clamp(0.0, 1.0) * plot.width,
      plot.bottom - (p.dy / yMax).clamp(0.0, 1.0) * plot.height,
    );

    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = const Color(0xFF46566F)
      ..strokeWidth = 1.6;
    const ticks = 5;
    for (var i = 0; i <= ticks; i++) {
      final f = i / ticks;
      final x = plot.left + f * plot.width;
      final y = plot.bottom - f * plot.height;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(canvas, tick(xMax * f), Offset(x, plot.bottom + 3), center: true);
      _label(
        canvas,
        tick(yMax * f),
        Offset(plot.left - 4, y - 6),
        alignRight: true,
      );
    }
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);

    for (final s in series) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i + 1 < s.points.length; i++) {
        final a = map(s.points[i]), b = map(s.points[i + 1]);
        if (s.dashed) {
          final len = (b - a).distance;
          final n = math.max(1, (len / 8).floor());
          for (var k = 0; k < n; k += 2) {
            canvas.drawLine(
              Offset.lerp(a, b, k / n)!,
              Offset.lerp(a, b, math.min(1, (k + 1) / n))!,
              paint,
            );
          }
        } else {
          canvas.drawLine(a, b, paint);
        }
      }
      if (s.showPoints) {
        for (final p in s.points) {
          canvas.drawCircle(map(p), 3, Paint()..color = s.color);
        }
      }
    }

    if (marker != null) {
      final m = map(marker!);
      final guide = Paint()
        ..color = markerColor.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(m.dx, plot.bottom), m, guide);
      canvas.drawLine(Offset(plot.left, m.dy), m, guide);
      canvas.drawCircle(m, 6, Paint()..color = markerColor);
      canvas.drawCircle(
        m,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    bool center = false,
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF46566F)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center
        ? at.dx - tp.width / 2
        : (alignRight ? at.dx - tp.width : at.dx);
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) =>
      old.xMax != xMax ||
      old.yMax != yMax ||
      old.marker != marker ||
      old.series != series;
}

/// Title, y-axis caption, the chart, x-axis caption and a legend. Captions are real widgets (readable + testable).
class LabeledLineChart extends StatelessWidget {
  final String title;
  final String xLabel;
  final String yLabel;
  final List<ChartSeries> series;
  final double xMax;
  final double yMax;
  final Offset? marker;
  final String? caption;
  final double height;

  const LabeledLineChart({
    super.key,
    required this.title,
    required this.xLabel,
    required this.yLabel,
    required this.series,
    required this.xMax,
    required this.yMax,
    this.marker,
    this.caption,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          yLabel,
          style: const TextStyle(fontSize: 11, color: Color(0xFF46566F)),
        ),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: LineChartPainter(
              series: series,
              xMax: xMax,
              yMax: yMax,
              marker: marker,
            ),
          ),
        ),
        Center(
          child: Text(
            xLabel,
            style: const TextStyle(fontSize: 11, color: Color(0xFF46566F)),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 3, color: s.color),
                  const SizedBox(width: 4),
                  Text(s.label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            if (marker != null)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: Color(0xFFDC2626)),
                  SizedBox(width: 4),
                  Text('Your current setting', style: TextStyle(fontSize: 11)),
                ],
              ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF46566F),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
