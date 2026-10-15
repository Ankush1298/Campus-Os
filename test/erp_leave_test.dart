import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_os/features/erp/erp_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Reset seed data before each test run to ensure strict isolation
    await LeaveService.instance.resetToSeedData();
  });

  group('P0: Student Leave Workflow & Authorization Tests', () {
    test('Authenticated student can submit a valid leave application and it persists', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(days: 2));
      final end = now.add(const Duration(days: 4));

      final leave = await LeaveService.instance.applyStudentLeave(
        authenticatedStudentId: '22CS1042',
        authenticatedStudentName: 'Aarav Sharma',
        leaveType: 'Hostel Outing',
        startDate: start,
        endDate: end,
        reason: 'Attending Google Developer Group hackathon in Gurgaon',
        destinationAddress: 'Cyber City, Gurgaon',
        emergencyContact: '+91 98765 00000',
      );

      expect(leave.id, startsWith('LEAVE-'));
      expect(leave.applicantId, equals('22CS1042'));
      expect(leave.status, equals(LeaveStatus.pending));
      expect(leave.durationDays, equals(3));
      expect(leave.auditTrail, isNotEmpty);
      expect(leave.auditTrail.first.action, equals('SUBMITTED'));

      // Check persistence via retrieval
      final studentLeaves = await LeaveService.instance.getStudentLeaves(studentId: '22CS1042');
      final found = studentLeaves.any((l) => l.id == leave.id);
      expect(found, isTrue);
    });

    test('Submission is rejected when end date precedes start date', () async {
      final now = DateTime.now();
      final start = now.add(const Duration(days: 4));
      final end = now.add(const Duration(days: 2)); // End before start

      expect(
        () => LeaveService.instance.applyStudentLeave(
          authenticatedStudentId: '22CS1042',
          authenticatedStudentName: 'Aarav Sharma',
          leaveType: 'Hostel Outing',
          startDate: start,
          endDate: end,
          reason: 'Valid substantive reason for test',
        ),
        throwsA(isA<ErpValidationException>().having(
          (e) => e.message,
          'message',
          contains('cannot precede'),
        )),
      );
    });

    test('Submission is rejected when reason is missing or shorter than 10 characters', () async {
      final now = DateTime.now();

      expect(
        () => LeaveService.instance.applyStudentLeave(
          authenticatedStudentId: '22CS1042',
          authenticatedStudentName: 'Aarav Sharma',
          leaveType: 'Home Visit',
          startDate: now.add(const Duration(days: 1)),
          endDate: now.add(const Duration(days: 2)),
          reason: 'Too short',
        ),
        throwsA(isA<ErpValidationException>()),
      );
    });

    test('Student can only view their own leave applications (Scoping Isolation)', () async {
      // 22CS1042 has leaves
      final student1Leaves = await LeaveService.instance.getStudentLeaves(studentId: '22CS1042');
      expect(student1Leaves, isNotEmpty);
      for (final l in student1Leaves) {
        expect(l.applicantId, equals('22CS1042'));
      }

      // Querying as another student returns only their own leaves, not student1's
      final student2Leaves = await LeaveService.instance.getStudentLeaves(studentId: '22CS9999');
      expect(student2Leaves, isEmpty);
    });

    test('Student can cancel their own PENDING leave application', () async {
      final now = DateTime.now();
      final leave = await LeaveService.instance.applyStudentLeave(
        authenticatedStudentId: '22CS1042',
        authenticatedStudentName: 'Aarav Sharma',
        leaveType: 'Hostel Outing',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 2)),
        reason: 'Family visit that is later cancelled by student',
      );

      final cancelled = await LeaveService.instance.cancelLeave(
        leaveId: leave.id,
        authenticatedStudentId: '22CS1042',
        cancellationReason: 'Plans changed',
      );

      expect(cancelled.status, equals(LeaveStatus.cancelled));
      expect(cancelled.auditTrail.last.action, equals('CANCELLED'));
    });

    test('Student cannot cancel another student\'s leave application', () async {
      final now = DateTime.now();
      final leave = await LeaveService.instance.applyStudentLeave(
        authenticatedStudentId: '22CS1042',
        authenticatedStudentName: 'Aarav Sharma',
        leaveType: 'Hostel Outing',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 2)),
        reason: 'Valid reason for applicant',
      );

      expect(
        () => LeaveService.instance.cancelLeave(
          leaveId: leave.id,
          authenticatedStudentId: '22CS9999', // Attacker / other student
        ),
        throwsA(isA<ErpAuthException>()),
      );
    });

    test('Cancellation is rejected if leave has already been approved or rejected', () async {
      // LEAVE-2026-002 is already approved in seed data
      expect(
        () => LeaveService.instance.cancelLeave(
          leaveId: 'LEAVE-2026-002',
          authenticatedStudentId: '22CS1042',
        ),
        throwsA(isA<ErpConflictException>()),
      );
    });
  });

  group('P0: Warden Review & Authorization Tests', () {
    test('Non-warden student cannot access warden inbox or make decisions', () async {
      expect(
        () => LeaveService.instance.getWardenInbox(
          wardenId: '22CS1042',
          role: 'student',
        ),
        throwsA(isA<ErpAuthException>()),
      );

      expect(
        () => LeaveService.instance.decideLeave(
          leaveId: 'LEAVE-2026-001',
          approverId: '22CS1042',
          approverName: 'Aarav Sharma',
          approverRole: 'student',
          approve: true,
        ),
        throwsA(isA<ErpAuthException>()),
      );
    });

    test('Authorized warden sees only students assigned to their hostel/department', () async {
      // Dr. Priya Sen (FAC-CS-08) is warden for Hostel Ganga / CSE students (e.g. 22CS1042)
      final priyaInbox = await LeaveService.instance.getWardenInbox(
        wardenId: 'FAC-CS-08',
        role: 'teacher',
        pendingOnly: true,
      );

      expect(priyaInbox, isNotEmpty);
      expect(priyaInbox.any((l) => l.applicantId == '22CS1042'), isTrue);

      // Prof. Rajesh Khanna (WARDEN-YAMUNA) is warden for Hostel Yamuna, NOT Hostel Ganga
      final yamunaInbox = await LeaveService.instance.getWardenInbox(
        wardenId: 'WARDEN-YAMUNA',
        role: 'teacher',
        pendingOnly: true,
      );

      // Should not see student 22CS1042 from Hostel Ganga
      expect(yamunaInbox.any((l) => l.applicantId == '22CS1042'), isFalse);
      // But should see 22EE2001 from Hostel Yamuna
      expect(yamunaInbox.any((l) => l.applicantId == '22EE2001'), isTrue);
    });

    test('Warden can approve an assigned pending leave and decision persists with audit trail', () async {
      final decided = await LeaveService.instance.decideLeave(
        leaveId: 'LEAVE-2026-001',
        approverId: 'FAC-CS-08',
        approverName: 'Dr. Priya Sen',
        approverRole: 'teacher',
        approve: true,
        remarks: 'Approved. Official hackathon representation confirmed.',
      );

      expect(decided.status, equals(LeaveStatus.approved));
      expect(decided.decidedBy, equals('Dr. Priya Sen'));
      expect(decided.decidedById, equals('FAC-CS-08'));
      expect(decided.decisionRemarks, contains('Official hackathon'));
      expect(decided.auditTrail.last.action, equals('APPROVED'));

      // Check student retrieval now reflects the approved status
      final studentLeaves = await LeaveService.instance.getStudentLeaves(studentId: '22CS1042');
      final leaveInDb = studentLeaves.firstWhere((l) => l.id == 'LEAVE-2026-001');
      expect(leaveInDb.status, equals(LeaveStatus.approved));
      expect(leaveInDb.decidedBy, equals('Dr. Priya Sen'));
    });

    test('Warden can reject an assigned pending leave with remarks', () async {
      final decided = await LeaveService.instance.decideLeave(
        leaveId: 'LEAVE-2026-001',
        approverId: 'FAC-CS-08',
        approverName: 'Dr. Priya Sen',
        approverRole: 'teacher',
        approve: false,
        remarks: 'Rejected: Attendance below mandatory minimum 75%.',
      );

      expect(decided.status, equals(LeaveStatus.rejected));
      expect(decided.decisionRemarks, contains('Attendance below mandatory'));
      expect(decided.auditTrail.last.action, equals('REJECTED'));
    });

    test('Duplicate decision / race condition on already decided leave is rejected', () async {
      // 1. Approve it first
      await LeaveService.instance.decideLeave(
        leaveId: 'LEAVE-2026-001',
        approverId: 'FAC-CS-08',
        approverName: 'Dr. Priya Sen',
        approverRole: 'teacher',
        approve: true,
      );

      // 2. Second concurrent decision should be rejected with conflict
      expect(
        () => LeaveService.instance.decideLeave(
          leaveId: 'LEAVE-2026-001',
          approverId: 'FAC-CS-08',
          approverName: 'Dr. Priya Sen',
          approverRole: 'teacher',
          approve: false,
        ),
        throwsA(isA<ErpConflictException>()),
      );
    });

    test('Unassigned warden cannot decide on a student outside their hostel', () async {
      // WARDEN-YAMUNA tries to approve Ganga student's leave
      expect(
        () => LeaveService.instance.decideLeave(
          leaveId: 'LEAVE-2026-001',
          approverId: 'WARDEN-YAMUNA',
          approverName: 'Prof. Rajesh Khanna',
          approverRole: 'teacher',
          approve: true,
        ),
        throwsA(isA<ErpAuthException>()),
      );
    });
  });

  group('P1 & P2: Employee ERP, Directory & Academic Profile Tests', () {
    test('Employee can submit leave application', () async {
      final now = DateTime.now();
      final empLeave = await LeaveService.instance.applyEmployeeLeave(
        employeeId: 'FAC-CS-12',
        employeeName: 'Prof. Amit Sharma',
        department: 'Computer Science & Engineering',
        leaveType: 'Sick Leave',
        startDate: now.add(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 4)),
        reason: 'Viral fever rest prescribed by health center',
      );

      expect(empLeave.applicantRole, equals('employee'));
      expect(empLeave.status, equals(LeaveStatus.pending));

      final myLeaves = await LeaveService.instance.getEmployeeLeaves(employeeId: 'FAC-CS-12');
      expect(myLeaves.any((l) => l.id == empLeave.id), isTrue);
    });

    test('Staff directory returns active employees with leave balances', () async {
      final directory = await LeaveService.instance.getEmployeeDirectory();
      expect(directory, isNotEmpty);
      final priya = directory.firstWhere((e) => e.id == 'FAC-CS-08');
      expect(priya.name, contains('Priya Sen'));
      expect(priya.leaveBalance['Casual'], isNotNull);
    });

    test('Student academic profile returns timetable and verified records', () async {
      final profile = await LeaveService.instance.getStudentAcademicProfile(
        studentId: '22CS1042',
        studentName: 'Aarav Sharma',
      );
      expect(profile.rollNo, equals('22CS1042'));
      expect(profile.timetable, isNotEmpty);
      expect(profile.officialRecords, isNotEmpty);
      expect(profile.cgpa, equals('8.74'));
    });
  });

  group('UI Integration & Widget Tests', () {
    testWidgets('ErpModule.getEntryPoint builds ErpPortalScreen cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ErpModule.getEntryPoint(context),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ERP & Leave Portal'), findsOneWidget);
      expect(find.text('Student Leave'), findsOneWidget);
      expect(find.text('Warden Inbox'), findsOneWidget);
      expect(find.text('Employee ERP'), findsOneWidget);
      expect(find.text('Academics'), findsOneWidget);
    });

    testWidgets('Student Leave tab displays apply form and validates input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErpPortalScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Look for submit button
      final submitFinder = find.text('Submit Official Leave Application');
      expect(submitFinder, findsOneWidget);

      // Tap submit with empty reason to trigger validation
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Reason cannot be empty'), findsOneWidget);
    });

    testWidgets('Bottom navigation tabs switch smoothly between ERP sections', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ErpPortalScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Academics tab
      await tester.tap(find.text('Academics'));
      await tester.pumpAndSettle();

      expect(find.text('Campus Residence & Warden Details'), findsOneWidget);
      expect(find.text('Academic Timetable'), findsOneWidget);
      expect(find.text('Official Institutional Records'), findsOneWidget);

      // Tap on Employee ERP tab
      await tester.tap(find.text('Employee ERP'));
      await tester.pumpAndSettle();

      expect(find.text('Apply Leave'), findsOneWidget);
      expect(find.text('Staff Directory'), findsOneWidget);
    });
  });
}
