import 'package:flutter/material.dart';

enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled;

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'PENDING';
      case LeaveStatus.approved:
        return 'APPROVED';
      case LeaveStatus.rejected:
        return 'REJECTED';
      case LeaveStatus.cancelled:
        return 'CANCELLED';
    }
  }

  Color get color {
    switch (this) {
      case LeaveStatus.pending:
        return const Color(0xFFF59E0B); // Amber / Warning
      case LeaveStatus.approved:
        return const Color(0xFF10B981); // Emerald / Success
      case LeaveStatus.rejected:
        return const Color(0xFFEF4444); // Red / Error
      case LeaveStatus.cancelled:
        return const Color(0xFF64748B); // Slate / Muted
    }
  }

  Color get backgroundColor {
    switch (this) {
      case LeaveStatus.pending:
        return const Color(0xFFFEF3C7);
      case LeaveStatus.approved:
        return const Color(0xFFD1FAE5);
      case LeaveStatus.rejected:
        return const Color(0xFFFEE2E2);
      case LeaveStatus.cancelled:
        return const Color(0xFFF1F5F9);
    }
  }

  static LeaveStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'cancelled':
      case 'canceled':
        return LeaveStatus.cancelled;
      case 'pending':
      default:
        return LeaveStatus.pending;
    }
  }
}

class LeaveAuditEntry {
  final String actorId;
  final String actorName;
  final String actorRole;
  final String action; // SUBMITTED, APPROVED, REJECTED, CANCELLED
  final String remarks;
  final DateTime timestamp;

  const LeaveAuditEntry({
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.remarks,
    required this.timestamp,
  });

  factory LeaveAuditEntry.fromJson(Map<String, dynamic> json) {
    return LeaveAuditEntry(
      actorId: json['actorId'] as String? ?? 'system',
      actorName: json['actorName'] as String? ?? 'System',
      actorRole: json['actorRole'] as String? ?? 'system',
      action: json['action'] as String? ?? 'ACTION',
      remarks: json['remarks'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'actorRole': actorRole,
      'action': action,
      'remarks': remarks,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class LeaveApplication {
  final String id;
  final String applicantId; // Student Roll No or Employee ID
  final String applicantName;
  final String applicantRole; // 'student' or 'employee'
  final String department;
  final String? hostel; // e.g. "Hostel Ganga, Room 204"
  final String? assignedWardenId; // e.g. "WARDEN01" or "FAC-CS-08"
  final String leaveType; // e.g. "Hostel Outing", "Medical Leave", "Casual Leave"
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? destinationAddress;
  final String? emergencyContact;
  final LeaveStatus status;
  final DateTime appliedAt;
  final String? decisionRemarks;
  final String? decidedBy; // Approver Name
  final String? decidedById; // Approver ID
  final DateTime? decidedAt;
  final List<LeaveAuditEntry> auditTrail;

  const LeaveApplication({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    required this.applicantRole,
    required this.department,
    this.hostel,
    this.assignedWardenId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.destinationAddress,
    this.emergencyContact,
    required this.status,
    required this.appliedAt,
    this.decisionRemarks,
    this.decidedBy,
    this.decidedById,
    this.decidedAt,
    this.auditTrail = const [],
  });

  int get durationDays {
    final diff = endDate.difference(startDate).inDays;
    return diff >= 0 ? diff + 1 : 1;
  }

  bool get isPending => status == LeaveStatus.pending;
  bool get isApproved => status == LeaveStatus.approved;
  bool get isRejected => status == LeaveStatus.rejected;
  bool get isCancelled => status == LeaveStatus.cancelled;

  LeaveApplication copyWith({
    String? id,
    String? applicantId,
    String? applicantName,
    String? applicantRole,
    String? department,
    String? hostel,
    String? assignedWardenId,
    String? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? destinationAddress,
    String? emergencyContact,
    LeaveStatus? status,
    DateTime? appliedAt,
    String? decisionRemarks,
    String? decidedBy,
    String? decidedById,
    DateTime? decidedAt,
    List<LeaveAuditEntry>? auditTrail,
  }) {
    return LeaveApplication(
      id: id ?? this.id,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      applicantRole: applicantRole ?? this.applicantRole,
      department: department ?? this.department,
      hostel: hostel ?? this.hostel,
      assignedWardenId: assignedWardenId ?? this.assignedWardenId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      decisionRemarks: decisionRemarks ?? this.decisionRemarks,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedById: decidedById ?? this.decidedById,
      decidedAt: decidedAt ?? this.decidedAt,
      auditTrail: auditTrail ?? this.auditTrail,
    );
  }

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    final rawAudit = json['auditTrail'] as List<dynamic>? ?? [];
    return LeaveApplication(
      id: json['id'] as String? ?? '',
      applicantId: json['applicantId'] as String? ?? '',
      applicantName: json['applicantName'] as String? ?? '',
      applicantRole: json['applicantRole'] as String? ?? 'student',
      department: json['department'] as String? ?? 'General',
      hostel: json['hostel'] as String?,
      assignedWardenId: json['assignedWardenId'] as String?,
      leaveType: json['leaveType'] as String? ?? 'General Leave',
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String? ?? '',
      destinationAddress: json['destinationAddress'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      status: LeaveStatus.fromString(json['status'] as String? ?? 'pending'),
      appliedAt: DateTime.tryParse(json['appliedAt'] as String? ?? '') ?? DateTime.now(),
      decisionRemarks: json['decisionRemarks'] as String?,
      decidedBy: json['decidedBy'] as String?,
      decidedById: json['decidedById'] as String?,
      decidedAt: json['decidedAt'] != null ? DateTime.tryParse(json['decidedAt'] as String) : null,
      auditTrail: rawAudit
          .map((e) => LeaveAuditEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'applicantId': applicantId,
      'applicantName': applicantName,
      'applicantRole': applicantRole,
      'department': department,
      'hostel': hostel,
      'assignedWardenId': assignedWardenId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      'destinationAddress': destinationAddress,
      'emergencyContact': emergencyContact,
      'status': status.name,
      'appliedAt': appliedAt.toIso8601String(),
      'decisionRemarks': decisionRemarks,
      'decidedBy': decidedBy,
      'decidedById': decidedById,
      'decidedAt': decidedAt?.toIso8601String(),
      'auditTrail': auditTrail.map((e) => e.toJson()).toList(),
    };
  }
}
