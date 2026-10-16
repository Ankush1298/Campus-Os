import 'package:flutter/material.dart';

class CircuitDiagramPainter extends CustomPainter {
  final double voltage;
  final double resistance;
  final double current;
  final Color accentColor;

  CircuitDiagramPainter({
    required this.voltage,
    required this.resistance,
    required this.current,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wirePaint = Paint()
      ..color = const Color(0xFF56667F)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final componentPaint = Paint()
      ..color = const Color(0xFF1B2B4B)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final batteryPaint = Paint()
      ..color = const Color(0xFF0E7C86)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: (current / 5.0).clamp(0.2, 0.8))
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final rect = Rect.fromLTWH(30, 20, size.width - 60, size.height - 40);

    // Glow wire effect based on current flow
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      glowPaint,
    );
    // Base wire loop
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      wirePaint,
    );

    // Left Side: DC Battery Source
    final batteryY = size.height / 2;
    final clearBatteryRect = Rect.fromLTWH(20, batteryY - 26, 20, 52);
    canvas.drawRect(clearBatteryRect, Paint()..color = const Color(0xFFF8FAFC));

    // Long plate (+)
    canvas.drawLine(
      Offset(22, batteryY - 18),
      Offset(38, batteryY - 18),
      batteryPaint,
    );
    // Short thick plate (-)
    canvas.drawLine(
      Offset(26, batteryY + 12),
      Offset(34, batteryY + 12),
      batteryPaint..strokeWidth = 5.0,
    );

    // Right Side: Resistor (Zig-zag)
    final resistorY = size.height / 2;
    final clearResistorRect = Rect.fromLTWH(
      size.width - 45,
      resistorY - 32,
      30,
      64,
    );
    canvas.drawRect(
      clearResistorRect,
      Paint()..color = const Color(0xFFF8FAFC),
    );

    final zigZagPath = Path();
    final rx = size.width - 30;
    zigZagPath.moveTo(rx, resistorY - 28);
    zigZagPath.lineTo(rx - 10, resistorY - 18);
    zigZagPath.lineTo(rx + 10, resistorY - 8);
    zigZagPath.lineTo(rx - 10, resistorY + 2);
    zigZagPath.lineTo(rx + 10, resistorY + 12);
    zigZagPath.lineTo(rx - 10, resistorY + 20);
    zigZagPath.lineTo(rx, resistorY + 28);
    canvas.drawPath(zigZagPath, componentPaint);

    // Top: Digital Ammeter
    final topX = size.width / 2;
    canvas.drawCircle(Offset(topX, 20), 16, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(topX, 20), 16, componentPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw 'A' inside ammeter circle
    textPainter.text = const TextSpan(
      text: 'A',
      style: TextStyle(
        color: Color(0xFF0B1B3A),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(topX - textPainter.width / 2, 20 - textPainter.height / 2),
    );

    // Draw Labels
    _drawLabel(
      canvas,
      '${voltage.toStringAsFixed(1)} V (DC)',
      Offset(8, batteryY - 40),
    );
    _drawLabel(
      canvas,
      '${resistance.toStringAsFixed(1)} Ω',
      Offset(size.width - 70, resistorY - 48),
    );
    _drawLabel(
      canvas,
      'Current: ${current.toStringAsFixed(2)} A',
      Offset(topX - 50, 42),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF0B1B3A),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CircuitDiagramPainter oldDelegate) {
    return oldDelegate.voltage != voltage ||
        oldDelegate.resistance != resistance ||
        oldDelegate.current != current;
  }
}
