import 'package:flutter/material.dart';

/// Where the logo is drawn: decides the colours.
enum CampusLogoTone {
  /// Navy arch with teal/periwinkle nodes, for light surfaces.
  onLight,

  /// White arch with teal/periwinkle nodes, for dark / navy surfaces.
  onDark,

  /// One flat colour (Android monochrome icon, watermarks).
  mono,
}

/// Brand palette used by the logo (the app theme re-exports these through AppColors).
class BrandColors {
  static const Color midnight = Color(0xFF0B1B3A);
  static const Color midnightDeep = Color(0xFF070F23);
  static const Color teal = Color(0xFF14B8C4);
  static const Color tealDeep = Color(0xFF0E7C86);
  static const Color periwinkle = Color(0xFF8B9CFF);
}

/// The CampusOS mark, drawn on a 100 x 100 grid.
///
/// Concept: an academic ARCH (the campus gateway) with an open entrance in its base (the pathway in);
/// inside it three nodes joined by a rising path (integrated services leading up and out).
/// It stays legible down to launcher size because it is only a stroke, a gap and three dots.
class CampusLogoPainter extends CustomPainter {
  final CampusLogoTone tone;
  final Color? monoColor;
  const CampusLogoPainter({this.tone = CampusLogoTone.onLight, this.monoColor});

  static const Offset n1 = Offset(36, 71);
  static const Offset n2 = Offset(60, 58);
  static const Offset n3 = Offset(47, 37);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);

    final mono = tone == CampusLogoTone.mono;
    final Color m = monoColor ?? Colors.white;

    // Arch: two legs with an entrance gap at the bottom, round caps.
    final arch = Path()
      ..moveTo(40, 86)
      ..lineTo(19, 86)
      ..lineTo(19, 50)
      ..arcToPoint(
        const Offset(81, 50),
        radius: const Radius.circular(31),
        clockwise: true,
      )
      ..lineTo(81, 86)
      ..lineTo(60, 86);
    final archPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (mono) {
      archPaint.color = m;
    } else if (tone == CampusLogoTone.onDark) {
      archPaint.shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFBFEFF3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(0, 15, 100, 75));
    } else {
      archPaint.shader = const LinearGradient(
        colors: [BrandColors.midnight, Color(0xFF16406E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(0, 15, 100, 75));
    }
    canvas.drawPath(arch, archPaint);

    // Pathway through the entrance up to the first node.
    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = mono ? m : BrandColors.teal;
    final route = Path()
      ..moveTo(50, 90)
      ..quadraticBezierTo(50, 77, n1.dx, n1.dy)
      ..lineTo(n2.dx, n2.dy)
      ..lineTo(n3.dx, n3.dy);
    canvas.drawPath(route, pathPaint);

    // Nodes (the connected campus services).
    final dot = Paint()..style = PaintingStyle.fill;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = tone == CampusLogoTone.onDark
          ? BrandColors.midnight
          : Colors.white;
    void node(Offset c, double r, Color color) {
      dot.color = mono ? m : color;
      canvas.drawCircle(c, r, dot);
      if (!mono) canvas.drawCircle(c, r, ring);
    }

    node(n1, 5.6, BrandColors.teal);
    node(n2, 6.6, BrandColors.periwinkle);
    node(n3, 5.6, BrandColors.teal);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CampusLogoPainter old) =>
      old.tone != tone || old.monoColor != monoColor;
}

/// Just the symbol.
class CampusLogoMark extends StatelessWidget {
  final double size;
  final CampusLogoTone tone;
  const CampusLogoMark({
    super.key,
    this.size = 40,
    this.tone = CampusLogoTone.onLight,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'CampusOS logo',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: CampusLogoPainter(tone: tone)),
    ),
  );
}

/// Symbol + "CampusOS" wordmark.
class CampusLogo extends StatelessWidget {
  final double markSize;
  final CampusLogoTone tone;
  final bool stacked;
  const CampusLogo({
    super.key,
    this.markSize = 40,
    this.tone = CampusLogoTone.onLight,
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = tone == CampusLogoTone.onDark;
    final word = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Campus',
            style: TextStyle(color: dark ? Colors.white : BrandColors.midnight),
          ),
          TextSpan(
            text: 'OS',
            style: TextStyle(
              color: dark ? BrandColors.teal : BrandColors.tealDeep,
            ),
          ),
        ],
      ),
      style: TextStyle(
        fontSize: markSize * 0.56,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1,
      ),
      textScaler: TextScaler.noScaling, // the wordmark is artwork: it must not grow with accessibility text size
    );
    final mark = CampusLogoMark(size: markSize, tone: tone);
    return stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(height: markSize * 0.22),
              word,
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(width: markSize * 0.2),
              word,
            ],
          );
  }
}
