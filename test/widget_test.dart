import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_os/app/campus_app.dart';
import 'package:campus_os/core/network/api_client.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/auth/services/auth_service.dart';
import 'package:campus_os/features/attendance/screens/attendance_screen.dart';
import 'package:campus_os/features/geocam/screens/geocam_screen.dart';
import 'package:campus_os/features/erp/erp_module.dart';
import 'package:campus_os/features/practiverse/practiverse_module.dart';

void main() {
  setUp(() async {
    // Reset session before each test
    AuthService.instance.currentSession.value = null;
    ApiClient.setAuthToken(null);
  });

  group('Core Unit Verifications', () {
    test('ApiClient.normalizeUrl formats hosts and schemes accurately', () {
      expect(ApiClient.normalizeUrl('192.168.1.50:8000/'), 'http://192.168.1.50:8000');
      expect(ApiClient.normalizeUrl('https://attendance.campus.edu/'), 'https://attendance.campus.edu');
      expect(ApiClient.normalizeUrl('   http://10.0.2.2:8000/   '), 'http://10.0.2.2:8000');
      expect(ApiClient.normalizeUrl(''), ApiClient.defaultUrl);
    });

    test('UserSession correctly detects expired and valid sessions', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final activeSession = UserSession(
        token: 'test-token',
        id: '22CS1042',
        name: 'Student',
        role: 'student',
        expiresAt: nowSeconds + 3600, // +1 hour
      );
      expect(activeSession.isExpired, isFalse);

      final expiredSession = UserSession(
        token: 'test-token',
        id: '22CS1042',
        name: 'Student',
        role: 'student',
        expiresAt: nowSeconds - 60, // -1 min
      );
      expect(expiredSession.isExpired, isTrue);

      final demoSession = UserSession.demoStudent();
      expect(demoSession.isExpired, isFalse);
    });
  });

  group('Demo and Integration Flows', () {
    testWidgets('Flow 1: App launches and displays CampusOS login screen', (WidgetTester tester) async {
      await tester.pumpWidget(const CampusApp());
      await tester.pumpAndSettle();

      expect(find.text('CampusOS'), findsWidgets);
      expect(find.text('Sign In to Your Campus Portal'), findsOneWidget);
      expect(find.text('Roll No / Faculty ID'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Instant Demo Access'), findsOneWidget);
    });

    testWidgets('Flow 2: Login UI validates missing inputs correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const CampusApp());
      await tester.pumpAndSettle();

      final idField = find.widgetWithText(TextField, 'Roll No / Faculty ID');
      final passField = find.widgetWithText(TextField, 'Password');

      await tester.enterText(idField, '');
      await tester.enterText(passField, '');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pump();

      // Verify error message banner
      expect(find.text('Please enter both ID and password'), findsOneWidget);
    });

    testWidgets('Flow 3: Demo login, mobile viewport rendering, and logout flow', (WidgetTester tester) async {
      // Set standard mobile screen size (390x844) to verify responsive rendering & no RenderFlex overflow
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const CampusApp());
      await tester.pumpAndSettle();

      // Tap Student demo login
      await tester.tap(find.widgetWithText(OutlinedButton, 'Student'));
      await tester.pumpAndSettle();

      // Verify Dashboard rendered with Student persona
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('CampusOS Modules'), findsOneWidget);

      // Verify all 4 module cards rendered cleanly without RenderFlex overflow
      expect(find.text('Smart Attendance System'), findsOneWidget);
      expect(find.text('GeoCam Camera Module'), findsOneWidget);
      expect(find.text('ERP & Leave Management'), findsOneWidget);
      expect(find.text('PractiVerse Labs'), findsOneWidget);

      // Verify logout dialog flow
      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Logout'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      // Back to Login
      expect(find.text('Sign In to Your Campus Portal'), findsOneWidget);
    });

    testWidgets('Flow 4: Smart Attendance Screen displays student demo data and status banner', (WidgetTester tester) async {
      AuthService.instance.currentSession.value = UserSession.demoStudent();

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Smart Attendance'), findsOneWidget);
      expect(find.text('Demo Mode — Displaying local simulated session data'), findsOneWidget);
      expect(find.text('ATTENDANCE RATE'), findsOneWidget);
      expect(find.text('87.5%'), findsOneWidget);
      expect(find.text('Data Structures & Algorithms'), findsOneWidget);
    });

    testWidgets('Flow 5: Smart Attendance Screen displays faculty overview correctly', (WidgetTester tester) async {
      AuthService.instance.currentSession.value = UserSession.demoFaculty();

      await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Smart Attendance'), findsOneWidget);
      expect(find.text('FACULTY AVERAGE PRESENCE'), findsOneWidget);
      expect(find.text('89.2%'), findsOneWidget);
      expect(find.text('36 lectures conducted'), findsOneWidget);
      expect(find.text('Advanced Database Systems'), findsOneWidget);
    });

    testWidgets('Flow 6: GeoCam Screen accurately represents preview simulation status', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: GeoCamScreen()));
      await tester.pumpAndSettle();

      expect(find.text('GeoCam Integration'), findsOneWidget);
      expect(find.text('GPS Status: '), findsOneWidget);
      expect(find.text('Simulate Geo-Stamp Preview'), findsOneWidget);

      // Info dialog verification
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('About GeoCam Engine'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Flow 7: ERP/Leave module entry point displays WIP contract for Person 2', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => ErpModule.getEntryPoint(context)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ERP & Leave Management'), findsOneWidget);
      expect(find.text('ERP & Leave Module'), findsOneWidget);
      expect(find.text('Branch: feature/erp-leave'), findsOneWidget);
    });

    testWidgets('Flow 8: PractiVerse module entry point displays WIP contract for Person 3', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) => PractiverseModule.getEntryPoint(context)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('PractiVerse'), findsOneWidget);
      expect(find.text('PractiVerse Lab Module'), findsOneWidget);
      expect(find.text('Branch: feature/practiverse'), findsOneWidget);
    });
  });
}
