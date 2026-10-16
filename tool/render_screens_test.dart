// Renders key screens to PNG for visual review (no device needed).
//   SHOT_DIR=/tmp/shots flutter test tool/render_screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:campus_os/app/campus_app.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/auth/services/auth_service.dart';
import 'package:campus_os/features/shell/app_shell.dart';
import 'package:campus_os/core/branding/brand_splash.dart';
import 'package:campus_os/features/practiverse/practiverse_module.dart';
import 'package:campus_os/features/geocam/screens/geocam_history_screen.dart';
import 'package:campus_os/features/geocam/services/geocam_history_store.dart';
import 'package:campus_os/features/dashboard/screens/profile_sheet.dart';
import 'package:campus_os/features/attendance/widgets/qr_scanner_sheet.dart';
import 'package:campus_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final dir = Platform.environment['SHOT_DIR'] ?? '/tmp/campusos_shots';

Future<void> shot(WidgetTester t, String name, {Size size = const Size(390, 844), double text = 1.0, Widget? home}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final key = GlobalKey();
  await t.pumpWidget(RepaintBoundary(key: key, child: MediaQuery(data: MediaQueryData(size: size, devicePixelRatio: 2, textScaler: TextScaler.linear(text), padding: const EdgeInsets.only(top: 28, bottom: 16)), child: home ?? const CampusApp())));
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
  await t.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    await Directory(dir).create(recursive: true);
    await File('$dir/$name.png').writeAsBytes(bytes);
  });
}

Widget tab(UserSession s, ShellTab tab) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AppShell(session: s, initialTab: tab),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter.ttf').readAsBytesSync())));
    await font.load();
  });

  testWidgets('login', (t) async {
    AuthService.instance.currentSession.value = null;
    await shot(t, '01_login');
  });
  testWidgets('home student', (t) async {
    AuthService.instance.currentSession.value = UserSession.demoStudent();
    await shot(t, '02_home_student');
  });
  testWidgets('home teacher', (t) async {
    AuthService.instance.currentSession.value = UserSession.demoFaculty();
    await shot(t, '03_home_teacher');
  });
  testWidgets('splash', (t) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(theme: AppTheme.lightTheme, debugShowCheckedModeBanner: false, home: const BrandSplash())));
    await t.pump();
    await t.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
      await Directory(dir).create(recursive: true);
      await File('$dir/00_splash.png').writeAsBytes((await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List());
    });
  });

  for (final e in {'04_attendance_student': ShellTab.attendance, '05_campus_student': ShellTab.campus, '06_geocam': ShellTab.capture, '07_learn': ShellTab.learn}.entries) {
    testWidgets(e.key, (t) async {
      final s = UserSession.demoStudent();
      AuthService.instance.currentSession.value = s;
      await shot(t, e.key, home: tab(s, e.value));
    });
  }
  testWidgets('08_attendance_teacher', (t) async {
    final s = UserSession.demoFaculty();
    AuthService.instance.currentSession.value = s;
    await shot(t, '08_attendance_teacher', home: tab(s, ShellTab.attendance));
  });
  testWidgets('09_campus_staff', (t) async {
    final s = UserSession.demoFaculty();
    AuthService.instance.currentSession.value = s;
    await shot(t, '09_campus_staff', home: tab(s, ShellTab.campus));
  });

  Widget app(Widget home) => MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, home: home);

  for (final id in ['physics_ohms_law', 'cs_sum_two_numbers']) {
    testWidgets('workspace $id', (t) async {
      final a = ActivityRegistry.allActivities.firstWhere((x) => x.id == id);
      await shot(t, '10_workspace_$id', size: const Size(390, 1700), home: app(ActivityWorkspaceScreen(activity: a, progress: StudentProgress())));
    });
  }
  testWidgets('geocam detail', (t) async {
    final r = GeoCamRecord(
      id: 'GEO-1792177888003',
      photoPath: '/nonexistent.jpg',
      timestamp: DateTime.utc(2026, 10, 16, 19, 43, 35),
      latitude: 25.033948,
      longitude: 74.634972,
      accuracy: 100,
      address: 'University Park, Gangrar, Rajasthan, 312901, India',
      sha256: 'a' * 64,
      signature: 'sig',
      publicKey: 'pub',
      syncStatus: 'syncFailed',
      syncError: 'Cannot reach verification server.',
    );
    await shot(t, '11_geocam_detail', size: const Size(390, 1500), home: app(GeoCamDetailScreen(record: r)));
  });
  testWidgets('profile sheet', (t) async {
    final s = UserSession.demoStudent();
    AuthService.instance.currentSession.value = s;
    await shot(t, '12_profile', home: app(Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => showProfileSheet(c, s), child: const Text('open')))))));
  });
  testWidgets('qr sheet', (t) async {
    final s = UserSession.demoStudent();
    await shot(t, '13_qr_sheet', home: app(Builder(builder: (c) => Scaffold(body: QrScannerSheet(session: s)))));
  });
}
