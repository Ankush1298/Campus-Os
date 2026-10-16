import 'package:flutter/material.dart';

class BeakerPainter extends CustomPainter {
  final double volumePercent; // 0.0 to 1.0 (fill fraction)
  final double concentration; // Molarity
  final Color baseSolutionColor;

  BeakerPainter({
    required this.volumePercent,
    required this.concentration,
    this.baseSolutionColor = const Color(0xFF0D9488),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glassPaint = Paint()
      ..color = const Color(0xFF2C3C58)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = const Color(0xFF56667F)
      ..strokeWidth = 1.5;

    // Beaker body geometry
    final left = 20.0;
    final right = size.width - 20.0;
    final top = 15.0;
    final bottom = size.height - 10.0;
    final lipLeft = left - 8.0;
    final lipRight = right + 8.0;

    // Solution Liquid Fill
    final liquidHeight = (bottom - top - 10) * volumePercent.clamp(0.05, 0.95);
    final liquidTop = bottom - liquidHeight;

    // Liquid opacity & color intensity reflects solute concentration
    final double intensity = (concentration / 4.0).clamp(0.2, 0.95);
    final liquidPaint = Paint()
      ..color = baseSolutionColor.withValues(alpha: intensity)
      ..style = PaintingStyle.fill;

    final liquidPath = Path()
      ..moveTo(left + 2, liquidTop)
      ..lineTo(right - 2, liquidTop)
      ..lineTo(right - 2, bottom - 4)
      ..quadraticBezierTo(right - 2, bottom, right - 6, bottom)
      ..lineTo(left + 6, bottom)
      ..quadraticBezierTo(left + 2, bottom, left + 2, bottom - 4)
      ..close();

    canvas.drawPath(liquidPath, liquidPaint);

    // Beaker Glass Outline
    final beakerPath = Path()
      ..moveTo(lipLeft, top)
      ..lineTo(left, top + 8)
      ..lineTo(left, bottom - 8)
      ..quadraticBezierTo(left, bottom, left + 8, bottom)
      ..lineTo(right - 8, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - 8)
      ..lineTo(right, top + 8)
      ..lineTo(lipRight, top);

    canvas.drawPath(beakerPath, glassPaint);

    // Measurement ticks
    for (int i = 1; i <= 4; i++) {
      final y = bottom - (bottom - top - 15) * (i / 4.0);
      canvas.drawLine(
        Offset(left, y),
        Offset(left + (i.isEven ? 14 : 8), y),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BeakerPainter oldDelegate) {
    return oldDelegate.volumePercent != volumePercent ||
        oldDelegate.concentration != concentration;
  }
}
