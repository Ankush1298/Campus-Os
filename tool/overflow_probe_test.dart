// Prints where RenderFlex overflows happen. flutter test tool/overflow_probe_test.dart
import 'package:campus_os/app/campus_app.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final cfg in [
    (const Size(320, 568), 1.0),
    (const Size(320, 640), 1.6),
  ]) {
    for (final s in [
      UserSession.demoStudent(),
      UserSession.demoFaculty(),
      UserSession.demoAdmin(),
    ]) {
      testWidgets('probe ${s.role} ${cfg.$1} ${cfg.$2}', (t) async {
        t.view.physicalSize = cfg.$1 * 2;
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        final seen = <String>{};
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final info = d
              .toDiagnosticsNode()
              .toStringDeep()
              .split('\n')
              .where((x) => x.contains('file:///') && x.contains('/lib/'))
              .take(2)
              .join(' | ');
          seen.add('${d.exceptionAsString().split('\n').first} @ $info');
        };
        AuthService.instance.currentSession.value = s;
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: cfg.$1,
              devicePixelRatio: 2,
              textScaler: TextScaler.linear(cfg.$2),
            ),
            child: const CampusApp(),
          ),
        );
        for (final tab in ['Home', 'Attendance', 'Campus', 'Learn']) {
          await t.tap(find.text(tab).last);
          await t.pump(const Duration(milliseconds: 700));
          await t.pump(const Duration(milliseconds: 700));
        }
        FlutterError.onError = old;
        for (final x in seen) {
          // ignore: avoid_print
          print('OVERFLOW ${s.role} ${cfg.$1} x${cfg.$2}: $x');
        }
      });
    }
  }
}
