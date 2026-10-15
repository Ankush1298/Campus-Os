import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../models/employee_profile.dart';
import '../models/leave_application.dart';
import '../models/student_academic_profile.dart';
import '../models/warden_assignment.dart';

class ErpValidationException implements Exception {
  final String message;
  const ErpValidationException(this.message);
  @override
  String toString() => message;
}

class ErpAuthException implements Exception {
  final String message;
  const ErpAuthException(this.message);
  @override
  String toString() => message;
}

class ErpConflictException implements Exception {
  final String message;
  const ErpConflictException(this.message);
  @override
  String toString() => message;
}

class LeaveService {
  static final LeaveService instance = LeaveService._internal();
  LeaveService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _storageKeyLeaves = 'campusos_erp_leaves_v1';

  bool _initialized = false;
  final List<LeaveApplication> _inMemoryLeaves = [];
  final List<EmployeeProfile> _inMemoryEmployees = [];
  final List<WardenAssignment> _wardenAssignments = [];

  List<LeaveApplication> get allLeaves => List.unmodifiable(_inMemoryLeaves);

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Setup default system warden assignments
    _initDefaultWardenAssignments();

    // 2. Setup default employee profiles
    _initDefaultEmployeeProfiles();

    // 3. Restore persisted leaves
    try {
      final jsonStr = await _storage.read(key: _storageKeyLeaves);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        _inMemoryLeaves.clear();
        for (final item in decoded) {
          _inMemoryLeaves.add(LeaveApplication.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('LeaveService: Note on storage read: $e');
    }

    // 4. Seed initial realistic demo applications if completely empty
    if (_inMemoryLeaves.isEmpty) {
      _seedInitialData();
      await _persistLeaves();
    }

    _initialized = true;
  }

  void _initDefaultWardenAssignments() {
    _wardenAssignments.clear();
    _wardenAssignments.addAll([
      const WardenAssignment(
        wardenId: 'FAC-CS-08',
        wardenName: 'Dr. Priya Sen',
        email: 'priya.sen@campusos.edu',
        phone: '+91 98765 43210',
        assignedHostels: ['Hostel Ganga', 'Ganga Block B'],
        assignedDepartments: ['Computer Science & Engineering', 'CSE'],
        assignedStudentIds: ['22CS1042', '22CS1043', '22CS1044', '22CS1045'],
      ),
      const WardenAssignment(
        wardenId: 'WARDEN-YAMUNA',
        wardenName: 'Prof. Rajesh Khanna',
        email: 'rajesh.khanna@campusos.edu',
        phone: '+91 98765 11223',
        assignedHostels: ['Hostel Yamuna', 'Yamuna Block A'],
        assignedDepartments: ['Electrical Engineering', 'EE'],
        assignedStudentIds: ['22EE2001', '22EE2002'],
      ),
      const WardenAssignment(
        wardenId: 'ADMIN01',
        wardenName: 'Campus SuperAdmin',
        email: 'admin@campusos.edu',
        phone: '+91 99999 00000',
        assignedHostels: ['Hostel Ganga', 'Hostel Yamuna', 'Hostel Kaveri'],
        assignedDepartments: ['*'],
        assignedStudentIds: ['*'],
      ),
    ]);
  }

  void _initDefaultEmployeeProfiles() {
    _inMemoryEmployees.clear();
    _inMemoryEmployees.addAll([
      const EmployeeProfile(
        id: 'FAC-CS-08',
        name: 'Dr. Priya Sen',
        department: 'Computer Science & Engineering',
        designation: 'Associate Professor & Chief Warden',
        email: 'priya.sen@campusos.edu',
        phone: '+91 98765 43210',
        status: 'Active',
        reportingManager: 'Dean of Academic Affairs',
        leaveBalance: {'Casual': 10, 'Sick': 8, 'Earned': 14, 'Duty': 5},
      ),
      const EmployeeProfile(
        id: 'FAC-CS-12',
        name: 'Prof. Amit Sharma',
        department: 'Computer Science & Engineering',
        designation: 'Assistant Professor',
        email: 'amit.sharma@campusos.edu',
        phone: '+91 98123 45678',
        status: 'Active',
        reportingManager: 'Dr. Priya Sen',
        leaveBalance: {'Casual': 8, 'Sick': 10, 'Earned': 12, 'Duty': 3},
      ),
      const EmployeeProfile(
        id: 'STAFF-ADM-03',
        name: 'Sunita Rao',
        department: 'Academic Section & Registrar',
        designation: 'Senior Administrative Officer',
        email: 'sunita.rao@campusos.edu',
        phone: '+91 94321 09876',
        status: 'Active',
        reportingManager: 'Registrar',
        leaveBalance: {'Casual': 12, 'Sick': 6, 'Earned': 20, 'Duty': 0},
      ),
      const EmployeeProfile(
        id: 'TECH-LAB-05',
        name: 'Rohan Mehra',
        department: 'IT Infrastructure & Labs',
        designation: 'Senior Systems Engineer',
        email: 'rohan.mehra@campusos.edu',
        phone: '+91 95555 44444',
        status: 'Active',
        reportingManager: 'Head of IT Services',
        leaveBalance: {'Casual': 9, 'Sick': 9, 'Earned': 15, 'Duty': 2},
      ),
    ]);
  }

  void _seedInitialData() {
    final now = DateTime.now();
    _inMemoryLeaves.addAll([
      LeaveApplication(
        id: 'LEAVE-2026-001',
        applicantId: '22CS1042',
        applicantName: 'Aarav Sharma',
        applicantRole: 'student',
        department: 'Computer Science & Engineering',
        hostel: 'Hostel Ganga (Block B)',
        assignedWardenId: 'FAC-CS-08',
        leaveType: 'Hostel Outing',
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 3)),
        reason: 'Attending Smart India Hackathon zonal round at IIT Delhi campus',
        destinationAddress: 'IIT Delhi, Hauz Khas, New Delhi',
        emergencyContact: '+91 98765 12345',
        status: LeaveStatus.pending,
        appliedAt: now.subtract(const Duration(hours: 4)),
        auditTrail: [
          LeaveAuditEntry(
            actorId: '22CS1042',
            actorName: 'Aarav Sharma',
            actorRole: 'student',
            action: 'SUBMITTED',
            remarks: 'Leave application submitted online with destination & emergency details',
            timestamp: now.subtract(const Duration(hours: 4)),
          ),
        ],
      ),
      LeaveApplication(
        id: 'LEAVE-2026-002',
        applicantId: '22CS1042',
        applicantName: 'Aarav Sharma',
        applicantRole: 'student',
        department: 'Computer Science & Engineering',
        hostel: 'Hostel Ganga (Block B)',
        assignedWardenId: 'FAC-CS-08',
        leaveType: 'Home Visit',
        startDate: now.subtract(const Duration(days: 14)),
        endDate: now.subtract(const Duration(days: 11)),
        reason: 'Family wedding ceremony at hometown',
        destinationAddress: 'Sector 14, Chandigarh',
        emergencyContact: '+91 98765 12345',
        status: LeaveStatus.approved,
        appliedAt: now.subtract(const Duration(days: 18)),
        decisionRemarks: 'Approved. Valid parental consent verified via SMS.',
        decidedBy: 'Dr. Priya Sen',
        decidedById: 'FAC-CS-08',
        decidedAt: now.subtract(const Duration(days: 17)),
        auditTrail: [
          LeaveAuditEntry(
            actorId: '22CS1042',
            actorName: 'Aarav Sharma',
            actorRole: 'student',
            action: 'SUBMITTED',
            remarks: 'Leave application submitted',
            timestamp: now.subtract(const Duration(days: 18)),
          ),
          LeaveAuditEntry(
            actorId: 'FAC-CS-08',
            actorName: 'Dr. Priya Sen',
            actorRole: 'warden',
            action: 'APPROVED',
            remarks: 'Approved. Valid parental consent verified via SMS.',
            timestamp: now.subtract(const Duration(days: 17)),
          ),
        ],
      ),
      LeaveApplication(
        id: 'LEAVE-2026-003',
        applicantId: '22EE2001',
        applicantName: 'Vikram Singh',
        applicantRole: 'student',
        department: 'Electrical Engineering',
        hostel: 'Hostel Yamuna',
        assignedWardenId: 'WARDEN-YAMUNA',
        leaveType: 'Medical Leave',
        startDate: now.add(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 5)),
        reason: 'Dental surgery and prescribed recovery bed rest',
        destinationAddress: 'Apex Hospital, Civil Lines',
        emergencyContact: '+91 98111 22334',
        status: LeaveStatus.pending,
        appliedAt: now.subtract(const Duration(hours: 1)),
        auditTrail: [
          LeaveAuditEntry(
            actorId: '22EE2001',
            actorName: 'Vikram Singh',
            actorRole: 'student',
            action: 'SUBMITTED',
            remarks: 'Medical leave submitted with clinic prescription reference',
            timestamp: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
      LeaveApplication(
        id: 'LEAVE-2026-EMP-01',
        applicantId: 'FAC-CS-12',
        applicantName: 'Prof. Amit Sharma',
        applicantRole: 'employee',
        department: 'Computer Science & Engineering',
        leaveType: 'Duty Leave',
        startDate: now.add(const Duration(days: 4)),
        endDate: now.add(const Duration(days: 6)),
        reason: 'Delivering keynote lecture at IEEE National Computing Conference',
        status: LeaveStatus.pending,
        appliedAt: now.subtract(const Duration(hours: 8)),
        auditTrail: [
          LeaveAuditEntry(
            actorId: 'FAC-CS-12',
            actorName: 'Prof. Amit Sharma',
            actorRole: 'employee',
            action: 'SUBMITTED',
            remarks: 'Duty leave application filed for conference attendance',
            timestamp: now.subtract(const Duration(hours: 8)),
          ),
        ],
      ),
    ]);
  }

  // ==========================================
  // P0: STUDENT LEAVE APPLICATION WORKFLOW
  // ==========================================

  Future<LeaveApplication> applyStudentLeave({
    required String authenticatedStudentId,
    required String authenticatedStudentName,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? destinationAddress,
    String? emergencyContact,
    String? department,
    String? hostel,
  }) async {
    await initialize();

    // 1. Strict Validation
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const ErpValidationException('Reason for leave is required.');
    }
    if (cleanReason.length < 10) {
      throw const ErpValidationException('Please provide a substantive reason (minimum 10 characters).');
    }
    if (leaveType.trim().isEmpty) {
      throw const ErpValidationException('Please select a valid leave category.');
    }

    // 2. Date Validation
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (endDay.isBefore(startDay)) {
      throw const ErpValidationException('Leave end date cannot precede the start date.');
    }

    final nowDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (startDay.isBefore(nowDay.subtract(const Duration(days: 2)))) {
      throw const ErpValidationException('Leave cannot be requested for past dates older than 48 hours.');
    }

    // 3. Resolve Assigned Warden according to student hostel / department
    final studentHostel = hostel ?? 'Hostel Ganga (Block B)';
    final studentDept = department ?? 'Computer Science & Engineering';

    String assignedWardenId = 'FAC-CS-08';
    for (final assignment in _wardenAssignments) {
      if (assignment.isStudentAssigned(
        studentId: authenticatedStudentId,
        hostel: studentHostel,
        department: studentDept,
      )) {
        assignedWardenId = assignment.wardenId;
        break;
      }
    }

    final newId = 'LEAVE-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final now = DateTime.now();

    final application = LeaveApplication(
      id: newId,
      applicantId: authenticatedStudentId, // Enforce authenticated identity
      applicantName: authenticatedStudentName,
      applicantRole: 'student',
      department: studentDept,
      hostel: studentHostel,
      assignedWardenId: assignedWardenId,
      leaveType: leaveType.trim(),
      startDate: startDay,
      endDate: endDay,
      reason: cleanReason,
      destinationAddress: destinationAddress?.trim(),
      emergencyContact: emergencyContact?.trim(),
      status: LeaveStatus.pending,
      appliedAt: now,
      auditTrail: [
        LeaveAuditEntry(
          actorId: authenticatedStudentId,
          actorName: authenticatedStudentName,
          actorRole: 'student',
          action: 'SUBMITTED',
          remarks: 'Leave request submitted via student portal',
          timestamp: now,
        ),
      ],
    );

    // 4. Atomic Persistence
    _inMemoryLeaves.insert(0, application);
    await _persistLeaves();

    // 5. Try syncing to real backend if available
    _trySyncBackendPost(application);

    return application;
  }

  Future<List<LeaveApplication>> getStudentLeaves({
    required String studentId,
  }) async {
    await initialize();
    // Return only leaves belonging to this authenticated student
    return _inMemoryLeaves
        .where((l) => l.applicantId == studentId && l.applicantRole == 'student')
        .toList();
  }

  Future<LeaveApplication> cancelLeave({
    required String leaveId,
    required String authenticatedStudentId,
    String? cancellationReason,
  }) async {
    await initialize();

    final index = _inMemoryLeaves.indexWhere((l) => l.id == leaveId);
    if (index == -1) {
      throw const ErpValidationException('Leave application not found.');
    }

    final current = _inMemoryLeaves[index];

    // Authorization check
    if (current.applicantId != authenticatedStudentId) {
      throw const ErpAuthException('Unauthorized: You cannot cancel another student\'s leave.');
    }

    // State transition guard
    if (current.status != LeaveStatus.pending) {
      throw ErpConflictException(
        'Cannot cancel leave: current status is ${current.status.displayName}. Only PENDING leaves can be cancelled.',
      );
    }

    final now = DateTime.now();
    final updatedAudit = List<LeaveAuditEntry>.from(current.auditTrail)
      ..add(
        LeaveAuditEntry(
          actorId: authenticatedStudentId,
          actorName: current.applicantName,
          actorRole: 'student',
          action: 'CANCELLED',
          remarks: cancellationReason ?? 'Cancelled by applicant student',
          timestamp: now,
        ),
      );

    final updated = current.copyWith(
      status: LeaveStatus.cancelled,
      auditTrail: updatedAudit,
    );

    _inMemoryLeaves[index] = updated;
    await _persistLeaves();

    return updated;
  }

  // ==========================================
  // P0: WARDEN INBOX & DECISION WORKFLOW
  // ==========================================

  Future<List<LeaveApplication>> getWardenInbox({
    required String wardenId,
    required String role,
    bool pendingOnly = true,
  }) async {
    await initialize();

    final normalizedRole = role.toLowerCase().trim();
    final isAuthorized = normalizedRole == 'admin' ||
        normalizedRole == 'teacher' ||
        normalizedRole == 'faculty' ||
        normalizedRole == 'warden';

    if (!isAuthorized) {
      throw const ErpAuthException('Access Denied: Warden or administrative privileges required.');
    }

    // Resolve assignment
    final isAdmin = normalizedRole == 'admin';
    WardenAssignment? assignment;
    for (final a in _wardenAssignments) {
      if (a.wardenId == wardenId) {
        assignment = a;
        break;
      }
    }

    return _inMemoryLeaves.where((leave) {
      if (leave.applicantRole != 'student') return false;
      if (pendingOnly && leave.status != LeaveStatus.pending) return false;

      if (isAdmin) return true; // SuperAdmin has institutional visibility

      if (assignment != null) {
        return assignment.isStudentAssigned(
          studentId: leave.applicantId,
          hostel: leave.hostel,
          department: leave.department,
        );
      }

      // Fallback matching by assignedWardenId
      return leave.assignedWardenId == wardenId;
    }).toList();
  }

  Future<LeaveApplication> decideLeave({
    required String leaveId,
    required String approverId,
    required String approverName,
    required String approverRole,
    required bool approve,
    String? remarks,
  }) async {
    await initialize();

    final normalizedRole = approverRole.toLowerCase().trim();
    final isAuthorized = normalizedRole == 'admin' ||
        normalizedRole == 'teacher' ||
        normalizedRole == 'faculty' ||
        normalizedRole == 'warden';

    if (!isAuthorized) {
      throw const ErpAuthException('Access Denied: You do not have approver privileges.');
    }

    final index = _inMemoryLeaves.indexWhere((l) => l.id == leaveId);
    if (index == -1) {
      throw const ErpValidationException('Leave application record not found.');
    }

    final current = _inMemoryLeaves[index];

    // Concurrency / duplicate-decision guard
    if (current.status != LeaveStatus.pending) {
      throw ErpConflictException(
        'Cannot decide on this application: it has already been decided (${current.status.displayName}) by ${current.decidedBy ?? "an approver"} on ${current.decidedAt?.toIso8601String().substring(0, 10) ?? "record"}.',
      );
    }

    // Scope check: Ensure approver is assigned to this student (unless admin)
    if (normalizedRole != 'admin') {
      bool isAssigned = false;
      for (final a in _wardenAssignments) {
        if (a.wardenId == approverId &&
            a.isStudentAssigned(
              studentId: current.applicantId,
              hostel: current.hostel,
              department: current.department,
            )) {
          isAssigned = true;
          break;
        }
      }
      if (!isAssigned && current.assignedWardenId != approverId) {
        throw const ErpAuthException(
          'Scope restriction: You are not assigned as warden for this student\'s hostel/department.',
        );
      }
    }

    final now = DateTime.now();
    final newStatus = approve ? LeaveStatus.approved : LeaveStatus.rejected;
    final cleanRemarks = remarks?.trim() ?? (approve ? 'Approved by Warden' : 'Rejected by Warden');

    final updatedAudit = List<LeaveAuditEntry>.from(current.auditTrail)
      ..add(
        LeaveAuditEntry(
          actorId: approverId,
          actorName: approverName,
          actorRole: approverRole,
          action: newStatus.displayName,
          remarks: cleanRemarks,
          timestamp: now,
        ),
      );

    final updated = current.copyWith(
      status: newStatus,
      decisionRemarks: cleanRemarks,
      decidedBy: approverName,
      decidedById: approverId,
      decidedAt: now,
      auditTrail: updatedAudit,
    );

    _inMemoryLeaves[index] = updated;
    await _persistLeaves();

    // Sync to backend if active
    _trySyncBackendDecision(updated);

    return updated;
  }

  // ==========================================
  // P1: EMPLOYEE LEAVE & HR WORKFLOW
  // ==========================================

  Future<LeaveApplication> applyEmployeeLeave({
    required String employeeId,
    required String employeeName,
    required String department,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    await initialize();

    final cleanReason = reason.trim();
    if (cleanReason.isEmpty || cleanReason.length < 5) {
      throw const ErpValidationException('Substantive reason is required for official leave record.');
    }

    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    if (endDay.isBefore(startDay)) {
      throw const ErpValidationException('End date cannot precede start date.');
    }

    final newId = 'LEAVE-EMP-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final now = DateTime.now();

    final application = LeaveApplication(
      id: newId,
      applicantId: employeeId,
      applicantName: employeeName,
      applicantRole: 'employee',
      department: department,
      leaveType: leaveType,
      startDate: startDay,
      endDate: endDay,
      reason: cleanReason,
      status: LeaveStatus.pending,
      appliedAt: now,
      auditTrail: [
        LeaveAuditEntry(
          actorId: employeeId,
          actorName: employeeName,
          actorRole: 'employee',
          action: 'SUBMITTED',
          remarks: 'Employee leave application submitted for department review',
          timestamp: now,
        ),
      ],
    );

    _inMemoryLeaves.insert(0, application);
    await _persistLeaves();
    return application;
  }

  Future<List<LeaveApplication>> getEmployeeLeaves({
    required String employeeId,
  }) async {
    await initialize();
    return _inMemoryLeaves
        .where((l) => l.applicantId == employeeId && l.applicantRole == 'employee')
        .toList();
  }

  Future<List<LeaveApplication>> getAllEmployeePendingLeaves({
    required String reviewerRole,
  }) async {
    await initialize();
    final normalized = reviewerRole.toLowerCase().trim();
    if (normalized != 'admin' && normalized != 'faculty' && normalized != 'teacher') {
      throw const ErpAuthException('Unauthorized to review employee leaves.');
    }

    return _inMemoryLeaves
        .where((l) => l.applicantRole == 'employee' && l.status == LeaveStatus.pending)
        .toList();
  }

  Future<List<EmployeeProfile>> getEmployeeDirectory() async {
    await initialize();
    return List.unmodifiable(_inMemoryEmployees);
  }

  Future<StudentAcademicProfile> getStudentAcademicProfile({
    required String studentId,
    required String studentName,
  }) async {
    return StudentAcademicProfile.defaultProfile(rollNo: studentId, name: studentName);
  }

  // ==========================================
  // PERSISTENCE & BACKEND SYNC HELPERS
  // ==========================================

  Future<void> _persistLeaves() async {
    try {
      final jsonList = _inMemoryLeaves.map((e) => e.toJson()).toList();
      await _storage.write(key: _storageKeyLeaves, value: jsonEncode(jsonList));
    } catch (e) {
      debugPrint('LeaveService: Note on storage write: $e');
    }
  }

  Future<void> _trySyncBackendPost(LeaveApplication app) async {
    try {
      await ApiClient.post('/api/erp/leaves', app.toJson());
    } catch (_) {
      // Backend not running locally - local persistent storage is the primary source of truth
    }
  }

  Future<void> _trySyncBackendDecision(LeaveApplication app) async {
    try {
      await ApiClient.post('/api/erp/leaves/${app.id}/decision', {
        'status': app.status.name,
        'remarks': app.decisionRemarks,
        'decidedBy': app.decidedBy,
        'decidedById': app.decidedById,
        'decidedAt': app.decidedAt?.toIso8601String(),
      });
    } catch (_) {
      // Offline fallback
    }
  }

  /// Reset to clean initial seed data (useful for demonstration / testing)
  Future<void> resetToSeedData() async {
    await initialize();
    _inMemoryLeaves.clear();
    _seedInitialData();
    await _persistLeaves();
  }
}
