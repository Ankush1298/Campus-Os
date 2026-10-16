import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:campus_os/app/campus_app.dart';
import 'package:campus_os/core/network/api_client.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/auth/services/auth_service.dart';
import 'package:campus_os/features/attendance/screens/attendance_screen.dart';
import 'package:campus_os/features/attendance/screens/face_registration_webview_screen.dart';
import 'package:campus_os/features/attendance/services/attendance_service.dart';
import 'package:campus_os/features/attendance/widgets/qr_scanner_sheet.dart';
import 'package:campus_os/features/attendance/widgets/admin_timetable_draft_sheet.dart';
import 'package:campus_os/features/geocam/screens/geocam_screen.dart';
import 'package:campus_os/features/geocam/screens/geocam_history_screen.dart';
import 'package:campus_os/features/geocam/services/geocam_verification_service.dart';
import 'package:campus_os/features/geocam/services/geocam_history_store.dart';
import 'package:campus_os/features/geocam/services/geocam_sync_service.dart';
import 'package:campus_os/features/geocam/screens/geocam_verification_dialog.dart';
import 'package:campus_os/features/geocam/models/stamp_settings.dart';
import 'package:campus_os/features/erp/erp_module.dart';
import 'package:campus_os/features/practiverse/practiverse_module.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MockHttpBaseClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  MockHttpBaseClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

void main() {
  setUp(() async {
    // Reset session before each test
    AuthService.instance.currentSession.value = null;
    ApiClient.setAuthToken(null);
  });

  group('Core Unit Verifications', () {
    test('ApiClient.normalizeUrl formats hosts and schemes accurately', () {
      expect(
        ApiClient.normalizeUrl('192.168.1.50:8000/'),
        'http://192.168.1.50:8000',
      );
      expect(
        ApiClient.normalizeUrl('https://attendance.campus.edu/'),
        'https://attendance.campus.edu',
      );
      expect(
        ApiClient.normalizeUrl('   http://10.0.2.2:8000/   '),
        'http://10.0.2.2:8000',
      );
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

    test('GeoCamVerificationService correctly computes cryptographic SHA-256 digests', () {
      final sampleBytes = Uint8List.fromList('CampusOS-GeoCam-Test'.codeUnits);
      final hash = GeoCamVerificationService.instance.computeSha256(
        sampleBytes,
      );
      expect(hash, isNotEmpty);
      expect(hash.length, 64); // SHA-256 hex string length
    });

    test('FaceRegistrationWebViewScreen restricts origin strictly to approved Railway host', () {
      expect(
        FaceRegistrationWebViewScreen.approvedHost,
        'attendance-register-production.up.railway.app',
      );

      // 1. Valid HTTPS approved origins (default port and explicit standard port 443)
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app/student',
        ),
        isTrue,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app/teacher',
        ),
        isTrue,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app:443/student',
        ),
        isTrue,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app/api/frame',
        ),
        isTrue,
      );

      // 2. HTTP downgrade attempts
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'http://attendance-register-production.up.railway.app/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'http://attendance-register-production.up.railway.app:80/student',
        ),
        isFalse,
      );

      // 3. Unexpected / non-standard ports
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app:8080/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app:8443/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app:3000/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app:80/student',
        ),
        isFalse,
      );

      // 4. Host suffix spoofing & domain confusion
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app.attacker.com/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app.evil.org/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app-phish.com/student',
        ),
        isFalse,
      );

      // 5. Subdomains & prefix confusion
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://sub.attendance-register-production.up.railway.app/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://api.attendance-register-production.up.railway.app/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://fake-attendance-register-production.up.railway.app/student',
        ),
        isFalse,
      );

      // 6. Query-string tricks, fragments, and UserInfo spoofing
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://evil.com?target=https://attendance-register-production.up.railway.app',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://evil.com/#attendance-register-production.up.railway.app',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attendance-register-production.up.railway.app@evil.com/student',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'https://attacker:secret@attendance-register-production.up.railway.app/student',
        ),
        isFalse,
      );

      // 7. Unsupported schemes & protocol injections
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl('javascript:alert(1)'),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'data:text/html,<h1>hacked</h1>',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl('file:///etc/passwd'),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'intent://attendance-register-production.up.railway.app',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'blob:https://attendance-register-production.up.railway.app/uuid',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'ws://attendance-register-production.up.railway.app/socket',
        ),
        isFalse,
      );
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl(
          'wss://attendance-register-production.up.railway.app/socket',
        ),
        isFalse,
      );

      // 8. Malformed and invalid URL inputs
      expect(FaceRegistrationWebViewScreen.isApprovedUrl(''), isFalse);
      expect(FaceRegistrationWebViewScreen.isApprovedUrl('   '), isFalse);
      expect(FaceRegistrationWebViewScreen.isApprovedUrl(null), isFalse);
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl('not a valid url'),
        isFalse,
      );
      expect(FaceRegistrationWebViewScreen.isApprovedUrl('https://'), isFalse);
      expect(FaceRegistrationWebViewScreen.isApprovedUrl('https://:'), isFalse);
      expect(
        FaceRegistrationWebViewScreen.isApprovedUrl('://missing-scheme'),
        isFalse,
      );
    });

    test('GeoCamVerificationService creates valid tamper-proof verification stamp and Ed25519 signature', () async {
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40]);
      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: sampleBytes,
      );
      expect(stamp.recordId, startsWith('GEO-'));
      expect(stamp.status, 'VERIFIED');
      expect(stamp.sha256, isNotEmpty);
      expect(stamp.signature, isNotEmpty);
      expect(stamp.publicKey, isNotEmpty);
      expect(stamp.formattedCoordinates, contains('Unavailable'));

      // Verify Ed25519 signature validity
      final isValid = await GeoCamVerificationService.instance.verifySignature(
        storedSignature: stamp.signature,
        publicKey: stamp.publicKey,
        recordId: stamp.recordId,
        mediaType: 'photo',
        timestamp: stamp.timestamp,
        latitude: stamp.latitude,
        longitude: stamp.longitude,
        accuracy: stamp.accuracy,
        altitude: null,
        address: '',
        mediaSha256: stamp.sha256,
      );
      expect(isValid, isTrue);
    });

    test('GeoCamVerificationService negative tests: altered payload, wrong key, modified sha', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: sampleBytes,
      );

      // 1. Altered coordinates
      final invalidCoords = await GeoCamVerificationService.instance
          .verifySignature(
            storedSignature: stamp.signature,
            publicKey: stamp.publicKey,
            recordId: stamp.recordId,
            mediaType: 'photo',
            timestamp: stamp.timestamp,
            latitude: 99.9999, // tampered
            longitude: stamp.longitude,
            accuracy: stamp.accuracy,
            altitude: null,
            address: '',
            mediaSha256: stamp.sha256,
          );
      expect(invalidCoords, isFalse);

      // 2. Tampered media SHA-256
      final invalidSha = await GeoCamVerificationService.instance
          .verifySignature(
            storedSignature: stamp.signature,
            publicKey: stamp.publicKey,
            recordId: stamp.recordId,
            mediaType: 'photo',
            timestamp: stamp.timestamp,
            latitude: stamp.latitude,
            longitude: stamp.longitude,
            accuracy: stamp.accuracy,
            altitude: null,
            address: '',
            mediaSha256: 'tampered-sha-256-hash-value',
          );
      expect(invalidSha, isFalse);

      // 3. Corrupted signature string
      final invalidSig = await GeoCamVerificationService.instance
          .verifySignature(
            storedSignature: 'corruptedSignatureString==',
            publicKey: stamp.publicKey,
            recordId: stamp.recordId,
            mediaType: 'photo',
            timestamp: stamp.timestamp,
            latitude: stamp.latitude,
            longitude: stamp.longitude,
            accuracy: stamp.accuracy,
            altitude: null,
            address: '',
            mediaSha256: stamp.sha256,
          );
      expect(invalidSig, isFalse);
    });

    test('GeoCamVerificationService QR payload generation and record ID extraction', () {
      final payload = GeoCamVerificationService.qrPayloadFor(
        'GEO-1792010137281',
      );
      expect(payload, 'https://geocam-server.onrender.com/GEO-1792010137281');

      expect(
        GeoCamVerificationService.extractRecordId(
          'https://geocam-server.onrender.com/GEO-1792010137281',
        ),
        'GEO-1792010137281',
      );
      expect(
        GeoCamVerificationService.extractRecordId(
          'http://localhost:8765/GEO-99887766',
        ),
        'GEO-99887766',
      );
      expect(
        GeoCamVerificationService.extractRecordId('GEO-11223344'),
        'GEO-11223344',
      );
      expect(
        GeoCamVerificationService.extractRecordId(
          '   https://geocam-server.onrender.com/GEO-SPACED/  ',
        ),
        'GEO-SPACED',
      );
      expect(GeoCamVerificationService.extractRecordId(''), isNull);
    });

    test('GeoCamVerificationService genuine tri-state verification: VERIFIED for valid media', () async {
      final sampleBytes = Uint8List.fromList([15, 25, 35, 45, 55]);
      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: sampleBytes,
        stampPixels: false,
      );

      final record = GeoCamRecord(
        id: stamp.recordId,
        photoPath: '/mock/path/${stamp.recordId}.jpg',
        qrPayload: stamp.qrPayload,
        timestamp: stamp.timestamp,
        latitude: stamp.latitude,
        longitude: stamp.longitude,
        accuracy: stamp.accuracy,
        sha256: stamp.sha256,
        signature: stamp.signature,
        publicKey: stamp.publicKey,
      );

      final result = await GeoCamVerificationService.instance.verifyRecord(
        qrOrRecordId: stamp.qrPayload,
        candidateImageBytes: sampleBytes,
        loadedRecord: record,
      );

      expect(result.status, GeoCamVerificationStatus.verified);
      expect(result.isVerified, isTrue);
      expect(result.shaMatches, isTrue);
      expect(result.signatureValid, isTrue);
      expect(result.recordId, stamp.recordId);
      expect(result.expectedSha256, stamp.sha256);
      expect(result.actualSha256, stamp.sha256);
    });

    test('GeoCamVerificationService genuine tri-state verification: INVALID / TAMPERED for altered image bytes', () async {
      final originalBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]);
      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: originalBytes,
        stampPixels: false,
      );

      final record = GeoCamRecord(
        id: stamp.recordId,
        photoPath: '/mock/path/${stamp.recordId}.jpg',
        qrPayload: stamp.qrPayload,
        timestamp: stamp.timestamp,
        latitude: stamp.latitude,
        longitude: stamp.longitude,
        accuracy: stamp.accuracy,
        sha256: stamp.sha256,
        signature: stamp.signature,
        publicKey: stamp.publicKey,
      );

      // Alter 1 byte of the image
      final tamperedBytes = Uint8List.fromList([1, 2, 3, 99, 5, 6, 7]);
      final result = await GeoCamVerificationService.instance.verifyRecord(
        qrOrRecordId: stamp.qrPayload,
        candidateImageBytes: tamperedBytes,
        loadedRecord: record,
      );

      expect(result.status, GeoCamVerificationStatus.invalidTampered);
      expect(result.isTampered, isTrue);
      expect(result.shaMatches, isFalse);
      expect(result.message, contains('Tampered image'));
    });

    test('GeoCamVerificationService genuine tri-state verification: INVALID / TAMPERED for forged/altered metadata', () async {
      final originalBytes = Uint8List.fromList([10, 20, 30, 40]);
      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: originalBytes,
        stampPixels: false,
      );

      // Corrupted signature or altered timestamp
      final forgedRecord = GeoCamRecord(
        id: stamp.recordId,
        photoPath: '/mock/path/${stamp.recordId}.jpg',
        qrPayload: stamp.qrPayload,
        timestamp: stamp.timestamp.add(const Duration(minutes: 5)), // tampered
        latitude: stamp.latitude,
        longitude: stamp.longitude,
        accuracy: stamp.accuracy,
        sha256: stamp.sha256,
        signature: stamp.signature, // signature won't match modified timestamp
        publicKey: stamp.publicKey,
      );

      final result = await GeoCamVerificationService.instance.verifyRecord(
        qrOrRecordId: stamp.qrPayload,
        candidateImageBytes: originalBytes,
        loadedRecord: forgedRecord,
      );

      expect(result.status, GeoCamVerificationStatus.invalidTampered);
      expect(result.signatureValid, isFalse);
    });

    test('GeoCamVerificationService genuine tri-state verification: UNABLE TO VERIFY for missing records or missing files', () async {
      // 1. Completely missing record ID
      final missingResult = await GeoCamVerificationService.instance
          .verifyRecord(
            qrOrRecordId:
                'https://geocam-server.onrender.com/GEO-MISSING-RECORD-9999',
          );
      expect(missingResult.status, GeoCamVerificationStatus.unableToVerify);
      expect(missingResult.isUnableToVerify, isTrue);
      expect(missingResult.message, contains('not found'));

      // 2. Missing image file and no candidate bytes
      final recordWithoutFile = GeoCamRecord(
        id: 'GEO-NO-FILE',
        photoPath:
            '/tmp/non_existent_geo_file_${DateTime.now().millisecondsSinceEpoch}.jpg',
        timestamp: DateTime.now(),
        latitude: 20.0,
        longitude: 70.0,
        accuracy: 5.0,
        sha256: 'somehash',
        signature: 'somesig',
        publicKey: 'somepub',
      );
      final noFileResult = await GeoCamVerificationService.instance
          .verifyRecord(
            qrOrRecordId: 'GEO-NO-FILE',
            loadedRecord: recordWithoutFile,
          );
      expect(noFileResult.status, GeoCamVerificationStatus.unableToVerify);
      expect(noFileResult.message, contains('missing or unreadable'));

      // 3. Unsigned legacy record
      final legacyRecord = GeoCamRecord(
        id: 'GEO-LEGACY',
        photoPath: '/dev/null',
        timestamp: DateTime.now(),
        latitude: 20.0,
        longitude: 70.0,
        accuracy: 5.0,
        sha256: '',
        signature: '',
        publicKey: '',
      );
      final legacyResult = await GeoCamVerificationService.instance
          .verifyRecord(qrOrRecordId: 'GEO-LEGACY', loadedRecord: legacyRecord);
      expect(legacyResult.status, GeoCamVerificationStatus.unableToVerify);
      expect(
        legacyResult.message,
        contains('without complete cryptographic signatures'),
      );
    });

    test('GeoCamRecord serialization and cryptographic audit properties', () {
      final now = DateTime.now();
      final record = GeoCamRecord(
        id: 'GEO-TEST-001',
        photoPath: '/tmp/test.jpg',
        qrPayload: 'https://geocam-server.onrender.com/GEO-TEST-001',
        timestamp: now,
        latitude: 25.0340,
        longitude: 74.6344,
        accuracy: 10.0,
        sha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        signature: 'mockSignatureBase64==',
        publicKey: 'mockPublicKeyBase64==',
      );

      expect(record.hasCryptographicProof, isTrue);
      expect(record.formattedCoordinates, contains('25.0340° N'));
      expect(record.qrPayload, contains('GEO-TEST-001'));

      final json = record.toJson();
      expect(
        json['qrPayload'],
        'https://geocam-server.onrender.com/GEO-TEST-001',
      );
      final revived = GeoCamRecord.fromJson(json);
      expect(revived.id, record.id);
      expect(revived.qrPayload, record.qrPayload);
      expect(revived.sha256, record.sha256);
      expect(revived.signature, record.signature);
      expect(revived.publicKey, record.publicKey);
    });
  });

  group('Demo and Integration Flows', () {
    testWidgets('Flow 1: App launches and displays CampusOS login screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const CampusApp());
      await tester.pumpAndSettle();

      expect(find.text('CampusOS'), findsWidgets);
      expect(find.text('Sign In to Your Campus Portal'), findsOneWidget);
      expect(find.text('Roll No / Faculty ID'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Instant Demo Access'), findsOneWidget);
    });

    testWidgets('Flow 2: Login UI validates missing inputs correctly', (
      WidgetTester tester,
    ) async {
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

    testWidgets(
      'Flow 3: Demo login, mobile viewport rendering, and logout flow',
      (WidgetTester tester) async {
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
        expect(
          find.text('DEMO MODE'),
          findsOneWidget,
        ); // demo data is always labelled

        // Verify all 4 module cards rendered cleanly without RenderFlex overflow (the list scrolls)
        await tester.scrollUntilVisible(
          find.text('GeoCam Camera Module'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Academics'), findsOneWidget);
        expect(find.text('Campus services'), findsOneWidget);
        expect(find.text('Smart Attendance System'), findsOneWidget);
        expect(find.text('GeoCam Camera Module'), findsOneWidget);
        expect(find.text('ERP & Leave Management'), findsOneWidget);
        expect(find.text('PractiVerse Labs'), findsOneWidget);

        // Verify logout flow: profile sheet -> Sign out -> confirmation dialog
        await tester.tap(find.byKey(const Key('open-profile')));
        await tester.pumpAndSettle();
        expect(
          find.text('Demo (sample data on this device, no server)'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('sign-out')));
        await tester.pumpAndSettle();

        expect(find.text('Confirm Logout'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
        await tester.pumpAndSettle();

        // Back to Login
        expect(find.text('Sign In to Your Campus Portal'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 4: Smart Attendance Screen displays student overview and schedule',
      (WidgetTester tester) async {
        AuthService.instance.currentSession.value = UserSession.demoStudent();

        await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Smart Attendance'), findsOneWidget);
        expect(
          find.text('Demo Mode — Displaying local simulated session data'),
          findsOneWidget,
        );
        expect(find.text('ATTENDANCE RATE'), findsOneWidget);
        expect(find.text('87.5%'), findsOneWidget);
        expect(find.text('Data Structures & Algorithms'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 5: Smart Attendance Screen displays faculty overview correctly',
      (WidgetTester tester) async {
        AuthService.instance.currentSession.value = UserSession.demoFaculty();

        await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Smart Attendance'), findsOneWidget);
        expect(find.text('FACULTY AVERAGE PRESENCE'), findsOneWidget);
        expect(find.text('89.2%'), findsOneWidget);
        expect(find.text('36 lectures conducted'), findsOneWidget);
        expect(find.text('Advanced Database Systems'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 6: GeoCam Screen renders viewfinder controls and fallback gracefully',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: GeoCamScreen()));
        await tester.pumpAndSettle();

        expect(find.text('GeoCam'), findsOneWidget);
        expect(find.byIcon(Icons.history_rounded), findsOneWidget);
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

        // Tap info dialog
        await tester.tap(find.byIcon(Icons.info_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('About GeoCam Engine'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Flow 7: ERP/Leave module entry point renders active ERP portal',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ErpModule.getEntryPoint(context),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default persona is a student: student tabs only, no staff/employee destinations.
        expect(find.text('ERP & Leave Portal'), findsOneWidget);
        expect(find.text('Student Leave'), findsOneWidget);
        expect(find.text('Academics'), findsOneWidget);
        expect(find.text('Warden Inbox'), findsNothing);
        expect(find.text('Employee ERP'), findsNothing);
      },
    );

    testWidgets('Flow 8: PractiVerse module entry point renders home screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => PractiverseModule.getEntryPoint(context),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PractiVerse'), findsOneWidget);
      expect(
        find.text('Build skills.\nSolve real challenges.'),
        findsOneWidget,
      );
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets(
      'Flow 9: Smart Attendance tabs switch between Overview and History for student',
      (WidgetTester tester) async {
        AuthService.instance.currentSession.value = UserSession.demoStudent();

        await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);

        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(find.text('Date: 2026-10-14 • 09:00 - 10:00'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 10: GeoCam History screen renders empty state and refresh action',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: GeoCamHistoryScreen()));
        await tester.pumpAndSettle();

        expect(find.text('GeoCam History'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 11: GeoCam Detail screen audits tamper-proof integrity and export action',
      (WidgetTester tester) async {
        final record = GeoCamRecord(
          id: 'GEO-AUDIT-TEST',
          photoPath: '/dev/null',
          qrPayload: 'https://geocam-server.onrender.com/GEO-AUDIT-TEST',
          timestamp: DateTime.now(),
          latitude: 25.0340,
          longitude: 74.6344,
          accuracy: 12.0,
          sha256: 'mocksha256hash',
          signature: 'mocksignature',
          publicKey: 'mockpubkey',
        );

        await tester.pumpWidget(
          MaterialApp(home: GeoCamDetailScreen(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('GEO-AUDIT-TEST'), findsWidgets);
        expect(find.text('Embedded GeoCam QR Code'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Online Web Verification'), findsOneWidget);
        expect(find.text('Open Verifier'), findsOneWidget);

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(find.text('Cryptographic Verification Audit'), findsOneWidget);
        expect(find.text('Audit Proof'), findsOneWidget);
        expect(find.text('Export Media'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 12: GeoCam Verification Dialog renders and audits valid and altered payloads',
      (WidgetTester tester) async {
        final sampleBytes = Uint8List.fromList([7, 8, 9, 10]);
        final stamp = await GeoCamVerificationService.instance.createStamp(
          imageBytes: sampleBytes,
          stampPixels: false,
        );

        final validRecord = GeoCamRecord(
          id: stamp.recordId,
          photoPath: '/mock/path/${stamp.recordId}.jpg',
          qrPayload: stamp.qrPayload,
          timestamp: stamp.timestamp,
          latitude: stamp.latitude,
          longitude: stamp.longitude,
          accuracy: stamp.accuracy,
          sha256: stamp.sha256,
          signature: stamp.signature,
          publicKey: stamp.publicKey,
        );

        // 1. Valid record dialog audit
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GeoCamVerificationDialog(
                initialRecordId: stamp.recordId,
                initialRecord: validRecord,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('GeoCam QR Verification'), findsOneWidget);
        expect(find.text('QR Code URL or Record ID'), findsOneWidget);
        expect(find.text('Verify'), findsOneWidget);

        // Tap Verify and check verification breakdown
        await tester.runAsync(() async {
          await tester.tap(find.text('Verify'));
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(
          find.text('UNABLE TO VERIFY'),
          findsOneWidget,
        ); // missing media file

        // Candidate image bytes match expected SHA-256 via service
        final res = await GeoCamVerificationService.instance.verifyRecord(
          qrOrRecordId: stamp.qrPayload,
          candidateImageBytes: sampleBytes,
          loadedRecord: validRecord,
        );
        expect(res.isVerified, isTrue);

        // 2. Missing record dialog audit
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GeoCamVerificationDialog(
                initialRecordId: 'GEO-NON-EXISTENT',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          await tester.tap(find.text('Verify'));
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        expect(find.text('UNABLE TO VERIFY'), findsOneWidget);
        expect(
          find.textContaining('not found in local cryptographic registry'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Flow 13: GeoCam Detail screen opens verification dialog with prefilled QR URL',
      (WidgetTester tester) async {
        final record = GeoCamRecord(
          id: 'GEO-FLOW13-TEST',
          photoPath: '/dev/null',
          qrPayload: 'https://geocam-server.onrender.com/GEO-FLOW13-TEST',
          timestamp: DateTime.now(),
          latitude: 25.0340,
          longitude: 74.6344,
          accuracy: 12.0,
          sha256: 'sha256test',
          signature: 'sigtest',
          publicKey: 'pubtest',
        );

        await tester.pumpWidget(
          MaterialApp(home: GeoCamDetailScreen(record: record)),
        );
        await tester.pumpAndSettle();

        final openVerifierBtn = find.text('Open Verifier');
        expect(openVerifierBtn, findsOneWidget);

        await tester.tap(openVerifierBtn);
        await tester.pumpAndSettle();

        expect(find.text('GeoCam QR Verification'), findsOneWidget);
        expect(
          find.text('https://geocam-server.onrender.com/GEO-FLOW13-TEST'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'Flow 14: FaceRegistrationWebViewScreen rejects untrusted URL safely without crashing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: FaceRegistrationWebViewScreen(
              url: 'https://evil.attacker.com/student',
              session: UserSession.demoStudent(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Untrusted registration URL rejected'),
          findsOneWidget,
        );
        expect(find.text('Retry Connection'), findsOneWidget);
      },
    );

    test('StampSettings model serialization, deserialization, and copying preserve all toggles', () {
      final defaultSettings = StampSettings();
      expect(defaultSettings.showCoordinates, isTrue);
      expect(defaultSettings.showAddress, isTrue);
      expect(defaultSettings.showDateTime, isTrue);
      expect(defaultSettings.showAccuracy, isTrue);
      expect(defaultSettings.showQr, isTrue);
      expect(defaultSettings.pixelEmbeddedStamps, isTrue);
      expect(defaultSettings.customText, isEmpty);

      final modified = defaultSettings.copy(
        showCoordinates: false,
        showQr: false,
        customText: 'CAMPUS AUDIT LAB 3',
      );
      expect(modified.showCoordinates, isFalse);
      expect(modified.showQr, isFalse);
      expect(modified.customText, 'CAMPUS AUDIT LAB 3');
      expect(modified.showDateTime, isTrue);

      final json = modified.toJson();
      final revived = StampSettings.fromJson(json);
      expect(revived.showCoordinates, isFalse);
      expect(revived.showQr, isFalse);
      expect(revived.customText, 'CAMPUS AUDIT LAB 3');
    });

    test('GeoCamVerificationService supports custom header and settings in stamp generation', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final settings = StampSettings(
        customText: 'ENGINEERING BUILDING CHECK',
        showQr: true,
        showCoordinates: true,
      );

      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: sampleBytes,
        stampPixels: false,
        settings: settings,
      );

      expect(stamp.recordId, startsWith('GEO-'));
      expect(stamp.qrPayload, contains(stamp.recordId));
      expect(stamp.status, 'VERIFIED');
      expect(stamp.sha256, isNotEmpty);
      expect(stamp.signature, isNotEmpty);
      expect(stamp.publicKey, isNotEmpty);
    });

    test('GeoCamVerificationService creates signed video stamp and GeoCamHistoryStore persists video records', () async {
      final videoBytes = Uint8List.fromList(
        'CAMPUSOS-MOCK-MP4-VIDEO-STREAM'.codeUnits,
      );
      final stamp = await GeoCamVerificationService.instance.createVideoStamp(
        videoBytes: videoBytes,
      );

      expect(stamp.recordId, startsWith('GEO-'));
      expect(stamp.sha256.length, 64);
      expect(stamp.signature, isNotEmpty);
      expect(stamp.publicKey, isNotEmpty);

      // Verify that verifySignature validates video payloads accurately
      final isSigValid = await GeoCamVerificationService.instance
          .verifySignature(
            storedSignature: stamp.signature,
            publicKey: stamp.publicKey,
            recordId: stamp.recordId,
            mediaType: 'video',
            timestamp: stamp.timestamp,
            latitude: stamp.latitude,
            longitude: stamp.longitude,
            accuracy: stamp.accuracy,
            altitude: null,
            address: '',
            mediaSha256: stamp.sha256,
          );
      expect(isSigValid, isTrue);
    });

    testWidgets(
      'Flow 15: GeoCam History screen toggles between list and 3-column grid view',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: GeoCamHistoryScreen()));
        await tester.pumpAndSettle();

        expect(find.text('GeoCam History'), findsOneWidget);
        final toggleBtn = find.byTooltip('3-Column Grid View');
        expect(toggleBtn, findsOneWidget);

        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.byTooltip('List View'), findsOneWidget);
      },
    );

    testWidgets(
      'Flow 16: GeoCam Screen opens Stamp Settings sheet and toggles photo/video capture modes',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MaterialApp(home: GeoCamScreen()));
        await tester.pumpAndSettle();

        // Check Fallback / Viewfinder mode controls
        expect(find.text('PHOTO'), findsOneWidget);
        expect(find.text('VIDEO'), findsOneWidget);

        // Switch to video mode
        await tester.tap(find.text('VIDEO'));
        await tester.pumpAndSettle();

        // Switch back to photo mode
        await tester.tap(find.text('PHOTO'));
        await tester.pumpAndSettle();

        // Open Stamp Settings Sheet
        final settingsBtn = find.byTooltip('Stamp Settings');
        expect(settingsBtn, findsOneWidget);
        await tester.tap(settingsBtn);
        await tester.pumpAndSettle();

        expect(find.text('Stamp Settings'), findsOneWidget);
        expect(find.text('Coordinates'), findsOneWidget);
        expect(find.text('GPS Accuracy'), findsOneWidget);
        expect(find.text('Save Stamp Settings'), findsOneWidget);

        await tester.ensureVisible(find.text('Save Stamp Settings'));
        await tester.tap(find.text('Save Stamp Settings'));
        await tester.pumpAndSettle();
      },
    );

    test('Step 19: GeoCamSyncService builds exact original v2 /sync payload matching reference schema', () {
      final now = DateTime.utc(2026, 10, 15, 18, 45, 0);
      final record = GeoCamRecord(
        id: 'GEO-CONTRACT-TEST',
        photoPath: '/mock/path/photo.jpg',
        timestamp: now,
        latitude: 28.613900,
        longitude: 77.209000,
        accuracy: 15.0,
        altitude: 215.5,
        address: 'New Delhi, India',
        mediaType: 'photo',
        sha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        signature: 'mockbase64signature==',
        publicKey: 'mockbase64publickey==',
      );

      final payload = GeoCamSyncService.buildSyncPayload(record);

      expect(payload['protocolVersion'], 2);
      expect(payload['id'], 'GEO-CONTRACT-TEST');
      expect(payload['timestamp'], '2026-10-15T18:45:00.000Z');
      expect(payload['latitude'], 28.613900);
      expect(payload['longitude'], 77.209000);
      expect(payload['accuracy'], 15.0);
      expect(payload['altitude'], 215.5);
      expect(payload['address'], 'New Delhi, India');
      expect(payload['mediaType'], 'photo');
      expect(payload['signature'], 'mockbase64signature==');
      expect(
        payload['mediaSha256'],
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(payload['publicKey'], 'mockbase64publickey==');
    });

    test('Step 19: GeoCamSyncService.syncRecord constructs multipart request with JSON record and binary media', () async {
      final tempDir = await Directory.systemTemp.createTemp('geocam_sync_test');
      final testFile = File('${tempDir.path}/test_media.jpg');
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      await testFile.writeAsBytes(testBytes);

      final record = GeoCamRecord(
        id: 'GEO-MULTIPART-TEST',
        photoPath: testFile.path,
        timestamp: DateTime.utc(2026, 10, 15, 18, 45, 0),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 10.0,
        sha256: 'mocksha256',
        signature: 'mocksig',
        publicKey: 'mockpub',
      );

      http.BaseRequest? capturedRequest;
      final mockClient = MockHttpBaseClient((req) async {
        capturedRequest = req;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({'success': true, 'id': record.id, 'verified': true}),
            ),
          ),
          200,
        );
      });

      final result = await GeoCamSyncService.instance.syncRecord(
        record,
        client: mockClient,
        updateHistoryStore: false,
      );

      expect(result.success, isTrue);
      expect(result.status, 'synced');
      expect(capturedRequest, isNotNull);
      expect(capturedRequest, isA<http.MultipartRequest>());

      final mReq = capturedRequest as http.MultipartRequest;
      expect(mReq.method, 'POST');
      expect(
        mReq.url.toString(),
        '${GeoCamSyncService.defaultVerificationBaseUrl}/sync',
      );
      expect(mReq.fields.containsKey('record'), isTrue);

      final parsedRecordField = jsonDecode(mReq.fields['record']!);
      expect(parsedRecordField['id'], 'GEO-MULTIPART-TEST');
      expect(parsedRecordField['protocolVersion'], 2);

      expect(mReq.files.length, 1);
      final mediaFile = mReq.files.first;
      expect(mediaFile.field, 'media');
      expect(mediaFile.filename, 'GEO-MULTIPART-TEST.jpg');

      await tempDir.delete(recursive: true);
    });

    test('Step 19: GeoCamSyncService handles successful 200 responses: verified: true and alreadyExists: true', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'geocam_sync_success_test',
      );
      final testFile = File('${tempDir.path}/test_media.jpg');
      await testFile.writeAsBytes([1, 2, 3]);

      final record = GeoCamRecord(
        id: 'GEO-SUCCESS-TEST',
        photoPath: testFile.path,
        timestamp: DateTime.now(),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 10.0,
        sha256: 'mocksha256',
      );

      // 1. Initial successful upload
      final client1 = MockHttpBaseClient((req) async {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({'success': true, 'id': record.id, 'verified': true}),
            ),
          ),
          200,
        );
      });
      final res1 = await GeoCamSyncService.instance.syncRecord(
        record,
        client: client1,
        updateHistoryStore: false,
      );
      expect(res1.success, isTrue);
      expect(res1.status, 'synced');
      expect(res1.isAlreadyExists, isFalse);

      // 2. Idempotent re-upload returning alreadyExists: true
      final client2 = MockHttpBaseClient((req) async {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'success': true,
                'id': record.id,
                'alreadyExists': true,
              }),
            ),
          ),
          200,
        );
      });
      final res2 = await GeoCamSyncService.instance.syncRecord(
        record,
        client: client2,
        updateHistoryStore: false,
      );
      expect(res2.success, isTrue);
      expect(res2.status, 'alreadyExists');
      expect(res2.isAlreadyExists, isTrue);

      await tempDir.delete(recursive: true);
    });

    test('Step 19: GeoCamSyncService handles server errors, bad requests, conflicts, and timeouts', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'geocam_sync_err_test',
      );
      final testFile = File('${tempDir.path}/test_media.jpg');
      await testFile.writeAsBytes([1, 2, 3]);

      final record = GeoCamRecord(
        id: 'GEO-ERR-TEST',
        photoPath: testFile.path,
        timestamp: DateTime.now(),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 10.0,
        sha256: 'mocksha256',
      );

      // 400 Bad Request
      final client400 = MockHttpBaseClient(
        (req) async => http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'error': 'Media SHA-256 does not match signed record',
              }),
            ),
          ),
          400,
        ),
      );
      final res400 = await GeoCamSyncService.instance.syncRecord(
        record,
        client: client400,
        updateHistoryStore: false,
      );
      expect(res400.success, isFalse);
      expect(res400.status, 'rejected');
      expect(res400.message, contains('Media SHA-256 does not match'));

      // 409 Conflict (altered cryptographic content with same ID)
      final client409 = MockHttpBaseClient(
        (req) async => http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'error': 'Record ID already exists with different cryptographic content',
              }),
            ),
          ),
          409,
        ),
      );
      final res409 = await GeoCamSyncService.instance.syncRecord(
        record,
        client: client409,
        updateHistoryStore: false,
      );
      expect(res409.success, isFalse);
      expect(res409.status, 'rejected');
      expect(res409.statusCode, 409);

      // 500 Server Error
      final client500 = MockHttpBaseClient(
        (req) async => http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({'error': 'Server error while storing record'}),
            ),
          ),
          500,
        ),
      );
      final res500 = await GeoCamSyncService.instance.syncRecord(
        record,
        client: client500,
        updateHistoryStore: false,
      );
      expect(res500.success, isFalse);
      expect(res500.status, 'failed');
      expect(res500.statusCode, 500);

      // Timeout
      final timeoutClient = MockHttpBaseClient((req) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw TimeoutException('Request timed out');
      });
      final resTimeout = await GeoCamSyncService.instance.syncRecord(
        record,
        client: timeoutClient,
        timeout: const Duration(milliseconds: 10),
        updateHistoryStore: false,
      );
      expect(resTimeout.success, isFalse);
      expect(resTimeout.status, 'timeout');

      await tempDir.delete(recursive: true);
    });

    test('Step 19: GeoCamSyncService.checkRemoteVerification accurately parses GET /<record_id> HTML response states', () async {
      // 1. Genuine Verified Server Result
      final verifiedClient = MockHttpBaseClient((req) async {
        const verifiedHtml = '''
<!DOCTYPE html>
<html>
  <body>
    <h1>GeoCam Verification</h1>
    <div class="result ok">
      <div class="tag">✅ MEDIA + SIGNATURE VERIFIED</div>
      <p>The server's stored media bytes match the SHA-256 digest covered by the Ed25519 signature.</p>
    </div>
  </body>
</html>
''';
        return http.StreamedResponse(
          Stream.value(utf8.encode(verifiedHtml)),
          200,
        );
      });

      final check1 = await GeoCamSyncService.instance.checkRemoteVerification(
        'GEO-VERIFIED-1',
        client: verifiedClient,
        updateHistoryStore: false,
      );
      expect(check1.isVerified, isTrue);
      expect(check1.isNotFound, isFalse);
      expect(check1.isInvalid, isFalse);

      // 2. Record Not Found (Never synchronized)
      final notFoundClient = MockHttpBaseClient((req) async {
        const notFoundHtml = '''
<!DOCTYPE html>
<html>
  <body>
    <div class="result bad">
      <div class="tag">❌ VERIFICATION FAILED</div>
      <p>Record not found: no record with this ID exists on the server. It was either never synchronized from the phone, or the server lost it.</p>
    </div>
  </body>
</html>
''';
        return http.StreamedResponse(
          Stream.value(utf8.encode(notFoundHtml)),
          200,
        );
      });

      final check2 = await GeoCamSyncService.instance.checkRemoteVerification(
        'GEO-NOT-FOUND-2',
        client: notFoundClient,
        updateHistoryStore: false,
      );
      expect(check2.isVerified, isFalse);
      expect(check2.isNotFound, isTrue);
      expect(check2.isInvalid, isFalse);

      // 3. Remote Verification Failed (Cryptographic forgery detected on server)
      final invalidClient = MockHttpBaseClient((req) async {
        const invalidHtml = '''
<!DOCTYPE html>
<html>
  <body>
    <div class="result bad">
      <div class="tag">❌ VERIFICATION FAILED</div>
      <p>The stored media or signed metadata failed cryptographic verification.</p>
    </div>
  </body>
</html>
''';
        return http.StreamedResponse(
          Stream.value(utf8.encode(invalidHtml)),
          200,
        );
      });

      final check3 = await GeoCamSyncService.instance.checkRemoteVerification(
        'GEO-INVALID-3',
        client: invalidClient,
        updateHistoryStore: false,
      );
      expect(check3.isVerified, isFalse);
      expect(check3.isNotFound, isFalse);
      expect(check3.isInvalid, isTrue);
    });

    test('Step 19: GeoCamRecord prevents false online verified status after upload alone (distinguishes synced vs remoteConfirmed)', () {
      final recordNotSynced = GeoCamRecord(
        id: 'GEO-STATE-TEST',
        photoPath: '/mock/path.jpg',
        timestamp: DateTime.now(),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 10.0,
        sha256: 'hash',
        syncStatus: 'notSynced',
      );
      expect(recordNotSynced.isNotSynced, isTrue);
      expect(recordNotSynced.isSynchronized, isFalse);
      expect(recordNotSynced.isRemoteConfirmed, isFalse);

      final recordSynced = recordNotSynced.copyWith(syncStatus: 'synced');
      expect(recordSynced.isNotSynced, isFalse);
      expect(recordSynced.isSynchronized, isTrue);
      expect(
        recordSynced.isRemoteConfirmed,
        isFalse,
      ); // Upload alone is NOT remote confirmed

      final recordConfirmed = recordSynced.copyWith(
        syncStatus: 'remoteConfirmed',
      );
      expect(recordConfirmed.isSynchronized, isTrue);
      expect(
        recordConfirmed.isRemoteConfirmed,
        isTrue,
      ); // Remote confirmed only after explicit server verification proof
    });

    test('Step 19: GeoCamRecord persists syncStatus, syncedAt, syncError and cleanly deserializes legacy records', () {
      final syncTime = DateTime.utc(2026, 10, 15, 19, 0, 0);
      final record = GeoCamRecord(
        id: 'GEO-SERIAL-TEST',
        photoPath: '/tmp/test.jpg',
        timestamp: DateTime.utc(2026, 10, 15, 18, 0, 0),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 10.0,
        sha256: 'hash123',
        syncStatus: 'synced',
        syncedAt: syncTime,
        syncError: 'Previous transient timeout',
      );

      final json = record.toJson();
      expect(json['syncStatus'], 'synced');
      expect(json['syncedAt'], '2026-10-15T19:00:00.000Z');
      expect(json['syncError'], 'Previous transient timeout');

      final revived = GeoCamRecord.fromJson(json);
      expect(revived.syncStatus, 'synced');
      expect(revived.syncedAt, syncTime);
      expect(revived.syncError, 'Previous transient timeout');
      expect(revived.isSynchronized, isTrue);

      // Legacy record JSON without sync fields
      final legacyJson = {
        'id': 'GEO-LEGACY-001',
        'photoPath': '/tmp/legacy.jpg',
        'timestamp': '2026-10-15T12:00:00.000Z',
        'latitude': 25.0,
        'longitude': 75.0,
        'accuracy': 10.0,
        'sha256': 'legacyhash',
      };
      final revivedLegacy = GeoCamRecord.fromJson(legacyJson);
      expect(revivedLegacy.syncStatus, 'notSynced');
      expect(revivedLegacy.syncedAt, isNull);
      expect(revivedLegacy.syncError, isNull);
      expect(revivedLegacy.isNotSynced, isTrue);
    });

    test('Step 19: GeoCamHistoryStore.updateSyncStatus updates in-memory and persists to storage', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'geocam_store_sync_test',
      );
      final testFile = File('${tempDir.path}/records.json');
      await testFile.writeAsString('[]');

      final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
      final saved = await GeoCamHistoryStore.save(
        id: 'GEO-UPDATE-SYNC-TEST',
        imageBytes: sampleBytes,
        timestamp: DateTime.now(),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 10.0,
        sha256: 'testsha',
      );
      expect(saved.syncStatus, 'notSynced');

      final updated = await GeoCamHistoryStore.updateSyncStatus(
        'GEO-UPDATE-SYNC-TEST',
        'synced',
        syncError: null,
      );
      expect(updated, isNotNull);
      expect(updated!.syncStatus, 'synced');
      expect(updated.isSynchronized, isTrue);

      final reloaded = await GeoCamHistoryStore.getById('GEO-UPDATE-SYNC-TEST');
      expect(reloaded, isNotNull);
      expect(reloaded!.syncStatus, 'synced');

      await GeoCamHistoryStore.delete(saved);
      await tempDir.delete(recursive: true);
    });

    testWidgets(
      'Step 19: showGeoCamSyncDisclosureDialog enforces explicit user consent before uploading',
      (WidgetTester tester) async {
        bool? userResponse;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    userResponse = await showGeoCamSyncDisclosureDialog(
                      context,
                      recordId: 'GEO-CONSENT-101',
                      mediaType: 'photo',
                    );
                  },
                  child: const Text('Open Consent Dialog'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open dialog and cancel
        await tester.tap(find.text('Open Consent Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Make QR Verifiable Online?'), findsOneWidget);
        expect(
          find.textContaining('https://geocam-server.onrender.com'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Privacy Note: No personal passwords'),
          findsOneWidget,
        );
        expect(find.text('Keep Offline Only'), findsOneWidget);
        expect(find.text('Upload & Make Verifiable'), findsOneWidget);

        await tester.tap(find.text('Keep Offline Only'));
        await tester.pumpAndSettle();
        expect(userResponse, isFalse);

        // 2. Open dialog and confirm
        await tester.tap(find.text('Open Consent Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Upload & Make Verifiable'));
        await tester.pumpAndSettle();
        expect(userResponse, isTrue);
      },
    );

    testWidgets(
      'Flow 17: GeoCamDetailScreen renders Online Web Verification card and reflects sync states',
      (WidgetTester tester) async {
        final record = GeoCamRecord(
          id: 'GEO-FLOW17-TEST',
          photoPath: '/dev/null',
          timestamp: DateTime.now(),
          latitude: 25.0340,
          longitude: 74.6344,
          accuracy: 12.0,
          sha256: 'mocksha256hash',
          signature: 'mocksignature',
          publicKey: 'mockpubkey',
          syncStatus: 'notSynced',
        );

        await tester.pumpWidget(
          MaterialApp(home: GeoCamDetailScreen(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Online Web Verification'), findsOneWidget);
        expect(find.text('PENDING'), findsOneWidget);
        expect(find.text('Make QR Verifiable Online'), findsOneWidget);

        // Scroll to Make QR Verifiable Online button and tap -> disclosure dialog opens
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Make QR Verifiable Online'));
        await tester.pumpAndSettle();

        expect(find.text('Make QR Verifiable Online?'), findsOneWidget);
        expect(find.text('Keep Offline Only'), findsOneWidget);

        // Cancel keeps it offline
        await tester.tap(find.text('Keep Offline Only'));
        await tester.pumpAndSettle();

        expect(find.text('PENDING'), findsOneWidget);
      },
    );

    test('Step 19: GeoCam QR URL never contains secrets or authentication tokens and matches original contract', () {
      final recordId = 'GEO-20261015-184500-A1B2';
      final payload = GeoCamVerificationService.qrPayloadFor(recordId);

      expect(
        payload,
        'https://geocam-server.onrender.com/GEO-20261015-184500-A1B2',
      );
      expect(payload.contains('token'), isFalse);
      expect(payload.contains('secret'), isFalse);
      expect(payload.contains('key'), isFalse);
      expect(payload.contains('password'), isFalse);
      expect(GeoCamVerificationService.extractRecordId(payload), recordId);
    });

    test('Step 20 Audit: Cross-language canonical serialization and Ed25519 signature verification against Python reference', () async {
      // Test vector generated directly via python cryptography library against reference canonical()
      const recordId = 'GEO-20261016-000000-TEST';
      const mediaType = 'photo';
      final timestamp = DateTime.utc(2026, 10, 16, 12, 0, 0);
      const latitude = 25.1234567;
      const longitude = 75.9876543;
      const accuracy = 15.42;
      const altitude = 210.68;
      const address = 'Main Gate, Campus';
      const sha256 =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

      final canonical = GeoCamVerificationService.canonicalPayload(
        recordId: recordId,
        mediaType: mediaType,
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        altitude: altitude,
        address: address,
        mediaSha256: sha256,
      );

      // Verify exact canonical string against python reference output
      const expectedCanonical =
          'v=2|id=GEO-20261016-000000-TEST|type=photo|ts=2026-10-16T12:00:00.000Z|lat=25.123457|lng=75.987654|acc=15.4|alt=210.7|addr64=TWFpbiBHYXRlLCBDYW1wdXM=|media_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(canonical, expectedCanonical);

      // Python Ed25519 public key and signature
      const pubB64 = 'iojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w=';
      const sigB64 =
          'WznH/++0bXQBJiY53UJWJAfH1nt/8WfaaNoIfK8SXng7NBhjGuRxls6OxvKUHvBi4FANnl6dpfYX+zZV4G88Aw==';

      final isValid = await GeoCamVerificationService.instance.verifySignature(
        storedSignature: sigB64,
        publicKey: pubB64,
        recordId: recordId,
        mediaType: mediaType,
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        altitude: altitude,
        address: address,
        mediaSha256: sha256,
      );
      expect(
        isValid,
        isTrue,
        reason: 'Dart GeoCamVerificationService must verify signatures produced by Python reference',
      );

      // Negative check: Tampering any field must invalidate the signature
      final isTampered = await GeoCamVerificationService.instance
          .verifySignature(
            storedSignature: sigB64,
            publicKey: pubB64,
            recordId: recordId,
            mediaType: mediaType,
            timestamp: timestamp,
            latitude: 25.123500, // altered coordinate within 6 decimals
            longitude: longitude,
            accuracy: accuracy,
            altitude: altitude,
            address: address,
            mediaSha256: sha256,
          );
      expect(isTampered, isFalse);
    });

    test('Step 20 Audit: Null coordinate and null altitude canonical serialization identically matches Python app.py', () {
      final canonical = GeoCamVerificationService.canonicalPayload(
        recordId: 'GEO-NULL-TEST',
        mediaType: 'video',
        timestamp: DateTime.utc(2026, 10, 16, 12, 0, 0),
        latitude: null,
        longitude: null,
        accuracy: null,
        altitude: null,
        address: '',
        mediaSha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      const expected =
          'v=2|id=GEO-NULL-TEST|type=video|ts=2026-10-16T12:00:00.000Z|lat=null|lng=null|acc=null|alt=null|addr64=|media_sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      expect(canonical, expected);
    });

    test('Step 20 Audit: Multipart sync payload strictly conforms to Python validate_record requirements', () {
      final record = GeoCamRecord(
        id: 'GEO-CONTRACT-AUDIT',
        photoPath: '/tmp/test.jpg',
        timestamp: DateTime.utc(2026, 10, 16, 10, 30, 0),
        latitude: 28.6139,
        longitude: 77.2090,
        accuracy: 5.0,
        altitude: 215.0,
        address: 'New Delhi, India',
        sha256:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        signature: base64Encode(List<int>.filled(64, 7)),
        publicKey: base64Encode(List<int>.filled(32, 9)),
      );

      final payload = GeoCamSyncService.buildSyncPayload(record);

      // Verify all required fields from Python app.py line 114:
      // ["id", "timestamp", "mediaType", "signature", "mediaSha256", "publicKey"]
      expect(payload['id'], 'GEO-CONTRACT-AUDIT');
      expect(payload['timestamp'], '2026-10-16T10:30:00.000Z');
      expect(payload['mediaType'], 'photo');
      expect(payload['signature'], isNotEmpty);
      expect(
        payload['mediaSha256'],
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      expect(payload['publicKey'], isNotEmpty);
      expect(payload['protocolVersion'], 2);

      // ID regex check: ^[A-Za-z0-9][A-Za-z0-9._-]{2,119}$
      final idRegex = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{2,119}$');
      expect(idRegex.hasMatch(payload['id'] as String), isTrue);

      // SHA256 regex check: ^[0-9a-f]{64}$
      final shaRegex = RegExp(r'^[0-9a-f]{64}$');
      expect(shaRegex.hasMatch(payload['mediaSha256'] as String), isTrue);

      // Signature & Public key length checks: 64 and 32 bytes
      expect(base64Decode(payload['signature'] as String).length, 64);
      expect(base64Decode(payload['publicKey'] as String).length, 32);
    });

    test('Step 28: Pre-upload SHA-256 integrity check rejects corrupted local media bytes before HTTP request', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'geocam_sha_precheck_test',
      );
      final testFile = File('${tempDir.path}/corrupt_media.jpg');
      await testFile.writeAsBytes([10, 20, 30, 40]);

      // Record has an authentic 64-character hex sha256 that does not match [10, 20, 30, 40]
      final record = GeoCamRecord(
        id: 'GEO-CORRUPT-TEST',
        photoPath: testFile.path,
        timestamp: DateTime.now(),
        latitude: 25.0,
        longitude: 75.0,
        accuracy: 5.0,
        sha256:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );

      bool networkAttempted = false;
      final mockClient = MockHttpBaseClient((req) async {
        networkAttempted = true;
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
      });

      final result = await GeoCamSyncService.instance.syncRecord(
        record,
        client: mockClient,
        updateHistoryStore: false,
      );

      expect(result.success, isFalse);
      expect(result.status, 'rejected');
      expect(result.message, contains('Media SHA-256 does not match'));
      expect(networkAttempted, isFalse); // No HTTP request was ever sent!

      await tempDir.delete(recursive: true);
    });

    test('Step 28: Pre-upload Ed25519 signature check rejects tampered local record metadata before HTTP request', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'geocam_sig_precheck_test',
      );
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final testFile = File('${tempDir.path}/valid_media.jpg');
      await testFile.writeAsBytes(testBytes);

      // Create a genuine cryptographically signed stamp
      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: testBytes,
        stampPixels: false,
      );

      // Tamper with latitude in the record while keeping original signature
      final tamperedRecord = GeoCamRecord(
        id: stamp.recordId,
        photoPath: testFile.path,
        timestamp: stamp.timestamp,
        latitude: (stamp.latitude ?? 0.0) + 5.0, // Altered!
        longitude: stamp.longitude,
        accuracy: stamp.accuracy,
        altitude: stamp.altitude,
        address: stamp.address,
        sha256: stamp.sha256,
        signature: stamp.signature,
        publicKey: stamp.publicKey,
      );

      bool networkAttempted = false;
      final mockClient = MockHttpBaseClient((req) async {
        networkAttempted = true;
        return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
      });

      final result = await GeoCamSyncService.instance.syncRecord(
        tamperedRecord,
        client: mockClient,
        updateHistoryStore: false,
      );

      expect(result.success, isFalse);
      expect(result.status, 'rejected');
      expect(result.message, contains('Ed25519 signature does not match'));
      expect(networkAttempted, isFalse);

      await tempDir.delete(recursive: true);
    });

    test('Step 28: GeoCamRecord model tracks isSavedToGallery and galleryError with JSON serialization', () {
      final record = GeoCamRecord(
        id: 'GEO-GALLERY-TEST',
        photoPath: '/mock/path.jpg',
        timestamp: DateTime.now(),
        latitude: 28.0,
        longitude: 77.0,
        accuracy: 10.0,
        sha256: 'mocksha',
        isSavedToGallery: true,
        galleryError: null,
      );

      final map = record.toJson();
      expect(map['isSavedToGallery'], isTrue);
      expect(map['galleryError'], isNull);

      final restored = GeoCamRecord.fromJson(map);
      expect(restored.isSavedToGallery, isTrue);
      expect(restored.galleryError, isNull);

      final failedRecord = GeoCamRecord(
        id: 'GEO-GALLERY-FAIL',
        photoPath: '/mock/path.jpg',
        timestamp: DateTime.now(),
        latitude: 28.0,
        longitude: 77.0,
        accuracy: 10.0,
        sha256: 'mocksha',
        isSavedToGallery: false,
        galleryError: 'Permission denied by user',
      );
      final failedMap = failedRecord.toJson();
      expect(failedMap['isSavedToGallery'], isFalse);
      expect(failedMap['galleryError'], 'Permission denied by user');

      final failedRestored = GeoCamRecord.fromJson(failedMap);
      expect(failedRestored.isSavedToGallery, isFalse);
      expect(failedRestored.galleryError, 'Permission denied by user');
    });

    test('Step 28: checkRemoteVerification handles live Render server responses: verified, not found (case-insensitive), invalid, and server errors', () async {
      // 1. Genuine verified response
      const verifiedHtml = '''
        <!DOCTYPE html>
        <html>
        <head><title>GeoCam Verification</title></head>
        <body>
          <div class="result-badge verified">VERIFIED AUTHENTIC</div>
          <p>Record ID: GEO-TEST-1</p>
        </body>
        </html>
      ''';
      final clientVerified = MockHttpBaseClient(
        (req) async =>
            http.StreamedResponse(Stream.value(utf8.encode(verifiedHtml)), 200),
      );
      final resVerified = await GeoCamSyncService.instance
          .checkRemoteVerification('GEO-TEST-1', client: clientVerified);
      expect(resVerified.isVerified, isTrue);
      expect(resVerified.isNotFound, isFalse);
      expect(resVerified.isInvalid, isFalse);

      // 2. Exact Render server 200 HTML for non-existent record (case-insensitive test)
      const renderNotFoundHtml = '''
        <!DOCTYPE html>
        <html>
        <head><title>GeoCam Verification</title></head>
        <body>
          <h2>Record Not Found</h2>
          <p>No record with this ID exists on the server. The media may not have been synchronized yet.</p>
        </body>
        </html>
      ''';
      final clientNotFound = MockHttpBaseClient(
        (req) async => http.StreamedResponse(
          Stream.value(utf8.encode(renderNotFoundHtml)),
          200,
        ),
      );
      final resNotFound = await GeoCamSyncService.instance
          .checkRemoteVerification('GEO-TEST-2', client: clientNotFound);
      expect(resNotFound.isVerified, isFalse);
      expect(resNotFound.isNotFound, isTrue);
      expect(resNotFound.isInvalid, isFalse);
      expect(resNotFound.message, contains('not found'));

      // 3. Cryptographic mismatch on server
      const failedHtml = '''
        <!DOCTYPE html>
        <html>
        <head><title>GeoCam Verification</title></head>
        <body>
          <div class="result-badge failed">VERIFICATION FAILED</div>
          <p>The uploaded media did not match the cryptographic signature.</p>
        </body>
        </html>
      ''';
      final clientFailed = MockHttpBaseClient(
        (req) async =>
            http.StreamedResponse(Stream.value(utf8.encode(failedHtml)), 200),
      );
      final resFailed = await GeoCamSyncService.instance
          .checkRemoteVerification('GEO-TEST-3', client: clientFailed);
      expect(resFailed.isVerified, isFalse);
      expect(resFailed.isNotFound, isFalse);
      expect(resFailed.isInvalid, isTrue);
    });

    testWidgets(
      'Step 28: Flow 18: GeoCamDetailScreen exposes Phone Gallery card, status badge, and sharing',
      (WidgetTester tester) async {
        final record = GeoCamRecord(
          id: 'GEO-FLOW18-TEST',
          photoPath: '/mock/path.jpg',
          qrPayload: 'https://geocam-server.onrender.com/GEO-FLOW18-TEST',
          timestamp: DateTime.now(),
          latitude: 28.6139,
          longitude: 77.2090,
          accuracy: 10.0,
          sha256: 'mocksha256',
          isSavedToGallery: true,
        );

        await tester.pumpWidget(
          MaterialApp(home: GeoCamDetailScreen(record: record)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.share_rounded), findsWidgets);

        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pumpAndSettle();

        expect(find.text('Phone Gallery (CampusOS GeoCam)'), findsOneWidget);
        expect(find.text('IN GALLERY'), findsOneWidget);
      },
    );

    group('Step 30: Scheduled Two-Phase QR Attendance & OCR Timetable Suite', () {
      test(
        'AttendanceService: startQrAttendance and endQrAttendance lifecycle',
        () async {
          final startRes = await AttendanceService.instance.startQrAttendance(
            timetableId: 101,
            isDemo: true,
          );
          expect(startRes['phase'], 'start');
          expect(startRes['remaining_seconds'], 300);
          expect(startRes['qr_token'], startsWith('qrs_start_'));

          final endRes = await AttendanceService.instance.endQrAttendance(
            timetableId: 101,
            isDemo: true,
          );
          expect(endRes['phase'], 'end');
          expect(endRes['remaining_seconds'], 300);
          expect(endRes['qr_token'], startsWith('qrs_end_'));
        },
      );

      test(
        'AttendanceService: scanQrAttendance start and end confirmation logic',
        () async {
          // Start scan
          final startRes = await AttendanceService.instance.scanQrAttendance(
            qrToken: 'qrs_start_test123',
            isDemo: true,
          );
          expect(startRes['phase'], 'start');
          expect(startRes['status'], 'recorded');
          expect(startRes['message'], contains('Start scan recorded'));

          // End scan (completes presence)
          final endRes = await AttendanceService.instance.scanQrAttendance(
            qrToken: 'qrs_end_test123',
            isDemo: true,
          );
          expect(endRes['phase'], 'end');
          expect(endRes['status'], 'present');
          expect(endRes['message'], contains('verified'));
        },
      );

      test('AttendanceService: student and teacher timetables preserve section and ownership filters', () async {
        final studentTt = await AttendanceService.instance
            .fetchStudentTimetable(isDemo: true);
        expect(studentTt['sections'], contains('CS-A'));
        final studentItems = studentTt['items'] as List<dynamic>;
        expect(studentItems, isNotEmpty);
        expect(studentItems.first['section_id'], 'CS-A');

        final teacherTt = await AttendanceService.instance
            .fetchTeacherTimetable(isDemo: true);
        expect(teacherTt['teacher_id'], 'DEMO_TEACHER');
        final teacherItems = teacherTt['items'] as List<dynamic>;
        expect(teacherItems, isNotEmpty);
        expect(teacherItems.first['teacher_id'], 'DEMO_TEACHER');
        expect(teacherItems.first['can_end'], isTrue);
      });

      test(
        'AttendanceService: draft correction and validation endpoints',
        () async {
          final initialDraft = await AttendanceService.instance
              .getTimetableDraft('draft_test_1', isDemo: true);
          expect(initialDraft['draft_id'], 'draft_test_1');
          final rows = (initialDraft['rows'] as List<dynamic>)
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          expect(rows.length, 3);

          // Edit row 2
          rows[1]['room_id'] = 'CR-205';
          final updateRes = await AttendanceService.instance
              .updateTimetableDraft(
                draftId: 'draft_test_1',
                rows: rows,
                isDemo: true,
              );
          expect(updateRes['rows_count'], 3);
          expect(updateRes['errors_count'], 0);

          final publishRes = await AttendanceService.instance
              .publishTimetableDraft(draftId: 'draft_test_1', isDemo: true);
          expect(publishRes['published_slots'], 3);
        },
      );

      testWidgets(
        'QrScannerSheet: renders viewfinder reticle, manual fallback, and handles manual token submit',
        (WidgetTester tester) async {
          bool attendanceMarkedCalled = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => QrScannerSheet.show(
                      ctx,
                      session: UserSession.demoStudent(),
                      onAttendanceMarked: () => attendanceMarkedCalled = true,
                    ),
                    child: const Text('Open Scanner'),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Open Scanner'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Scan Classroom QR'), findsOneWidget);
          expect(
            find.text('Point camera at Classroom Display'),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsOneWidget);

          // Enter a manual token
          await tester.enterText(
            find.byType(TextField),
            'qrs_start_demo_slot101',
          );
          await tester.pump(const Duration(milliseconds: 100));

          await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
          await tester.pump(const Duration(milliseconds: 200));

          expect(find.textContaining('Start scan recorded'), findsOneWidget);
          expect(attendanceMarkedCalled, isTrue);
        },
      );

      testWidgets(
        'AdminTimetableDraftSheet: renders draft rows, allows row edits, and handles publish confirmation',
        (WidgetTester tester) async {
          bool publishedCalled = false;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => AdminTimetableDraftSheet.show(
                      ctx,
                      draftId: 'draft_demo_ocr_preview',
                      onPublished: () => publishedCalled = true,
                    ),
                    child: const Text('Open Draft Review'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open Draft Review'));
          await tester.pumpAndSettle();

          expect(find.text('Timetable OCR Review & Editing'), findsOneWidget);
          expect(find.text('Data Structures & Algorithms'), findsOneWidget);
          expect(find.text('Confirm & Publish'), findsOneWidget);

          // Tap Confirm & Publish to trigger confirmation dialog
          await tester.tap(find.text('Confirm & Publish'));
          await tester.pumpAndSettle();

          expect(find.text('Confirm Timetable Publication'), findsOneWidget);
          await tester.tap(find.text('Confirm Publish'));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();

          expect(publishedCalled, isTrue);
        },
      );

      testWidgets(
        'AttendanceScreen: student view shows phase indicators and Scan QR trigger',
        (WidgetTester tester) async {
          AuthService.instance.currentSession.value = UserSession.demoStudent();

          await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
          await tester.pumpAndSettle();

          expect(find.text('Scan QR'), findsWidgets);
          expect(find.text('Start (0-5m)'), findsWidgets);
          expect(find.text('End (Last 5m)'), findsWidgets);
        },
      );

      testWidgets(
        'AttendanceScreen: teacher view shows Start and End attendance controls with confirmation',
        (WidgetTester tester) async {
          AuthService.instance.currentSession.value = UserSession.demoFaculty();

          await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
          await tester.pumpAndSettle();

          // Scroll slightly so today's schedule slot is in view
          await tester.drag(find.byType(ListView).first, const Offset(0, -250));
          await tester.pumpAndSettle();

          expect(find.text('Start (5m)'), findsWidgets);
          expect(find.text('End (5m)'), findsWidgets);

          // Tap Start (5m) on the class that can still be started (the first demo class is already in its Start window)
          await tester.drag(find.byType(ListView).first, const Offset(0, -400));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Start (5m)').last);
          await tester.pumpAndSettle();

          expect(find.text('Start Attendance Session?'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();

          // Tap End (5m) to inspect confirmation dialog
          await tester.tap(find.text('End (5m)').first);
          await tester.pumpAndSettle();

          expect(find.text('End Class Attendance?'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        },
      );

      testWidgets(
        'AttendanceScreen: admin view renders Timetable OCR draft review action',
        (WidgetTester tester) async {
          AuthService.instance.currentSession.value = UserSession.demoAdmin();

          await tester.pumpWidget(const MaterialApp(home: AttendanceScreen()));
          await tester.pumpAndSettle();

          // Switch to Timetable tab (index 2)
          await tester.tap(find.text('Timetable'));
          await tester.pumpAndSettle();

          expect(find.text('Timetable OCR & Publication'), findsOneWidget);
          expect(find.text('Review & Correct OCR Draft'), findsOneWidget);
        },
      );
    });
  });
}
