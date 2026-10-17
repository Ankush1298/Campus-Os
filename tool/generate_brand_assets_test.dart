// Regenerates the Android launcher / splash PNGs from the vector logo painter.
// Run:  flutter test tool/generate_brand_assets_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:campus_os/core/branding/campus_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _png(
  String path,
  int px, {
  required void Function(Canvas c, double s) draw,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  draw(canvas, px.toDouble());
  final img = await rec.endRecording().toImage(px, px);
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  await File(path).create(recursive: true);
  await File(path).writeAsBytes(bytes);
}

void _mark(
  Canvas c,
  double s,
  CampusLogoTone tone, {
  double scale = 1,
  Color? mono,
}) {
  c.save();
  final inner = s * scale;
  c.translate((s - inner) / 2, (s - inner) / 2);
  CampusLogoPainter(tone: tone, monoColor: mono).paint(c, Size(inner, inner));
  c.restore();
}

void _navyBackground(Canvas c, double s, {double radius = 0}) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  final paint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF0B1B3A), Color(0xFF0E3A5C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);
  if (radius > 0) {
    c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
  } else {
    c.drawRect(rect, paint);
  }
}

void main() {
  test('generate launcher, adaptive, monochrome and splash PNGs', () async {
    const res = 'android/app/src/main/res';
    // Legacy square launcher icons (rounded navy tile + symbol).
    for (final e in {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    }.entries) {
      await _png(
        '$res/mipmap-${e.key}/ic_launcher.png',
        e.value,
        draw: (c, s) {
          _navyBackground(c, s, radius: s * 0.22);
          _mark(c, s, CampusLogoTone.onDark, scale: 0.78);
        },
      );
    }
    // Adaptive icon layers (108dp canvas, symbol kept inside the 66dp safe zone).
    for (final e in {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    }.entries) {
      await _png(
        '$res/mipmap-${e.key}/ic_launcher_foreground.png',
        e.value,
        draw: (c, s) => _mark(c, s, CampusLogoTone.onDark, scale: 0.6),
      );
      await _png(
        '$res/mipmap-${e.key}/ic_launcher_monochrome.png',
        e.value,
        draw: (c, s) =>
            _mark(c, s, CampusLogoTone.mono, scale: 0.6, mono: Colors.black),
      );
    }
    // Native splash symbol (centered by the launch theme).
    await _png(
      '$res/drawable-nodpi/ic_splash_logo.png',
      512,
      draw: (c, s) => _mark(c, s, CampusLogoTone.onDark, scale: 0.9),
    );
    // Store / README preview.
    await _png(
      'assets/brand/campusos_app_icon_512.png',
      512,
      draw: (c, s) {
        _navyBackground(c, s, radius: s * 0.22);
        _mark(c, s, CampusLogoTone.onDark, scale: 0.78);
      },
    );
    expect(File('$res/mipmap-xxxhdpi/ic_launcher.png').existsSync(), isTrue);
  });
}
