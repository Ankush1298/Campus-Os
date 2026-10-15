class WardenAssignment {
  final String wardenId;
  final String wardenName;
  final String email;
  final String phone;
  final List<String> assignedHostels;
  final List<String> assignedDepartments;
  final List<String> assignedStudentIds;

  const WardenAssignment({
    required this.wardenId,
    required this.wardenName,
    required this.email,
    required this.phone,
    required this.assignedHostels,
    required this.assignedDepartments,
    required this.assignedStudentIds,
  });

  bool isStudentAssigned({
    required String studentId,
    String? hostel,
    String? department,
  }) {
    if (assignedStudentIds.contains('*') || assignedStudentIds.contains(studentId)) {
      return true;
    }
    if (hostel != null) {
      for (final h in assignedHostels) {
        if (h == '*' || hostel.toLowerCase().contains(h.toLowerCase())) return true;
      }
    }
    if (department != null) {
      final deptLower = department.toLowerCase().trim();
      for (final d in assignedDepartments) {
        final dLower = d.toLowerCase().trim();
        if (dLower == '*' || deptLower == dLower) return true;
        final tokens = deptLower.split(RegExp(r'[\s/&,]+'));
        if (tokens.contains(dLower)) return true;
      }
    }
    return false;
  }

  factory WardenAssignment.fromJson(Map<String, dynamic> json) {
    return WardenAssignment(
      wardenId: json['wardenId'] as String? ?? '',
      wardenName: json['wardenName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      assignedHostels: List<String>.from(json['assignedHostels'] as List? ?? []),
      assignedDepartments: List<String>.from(json['assignedDepartments'] as List? ?? []),
      assignedStudentIds: List<String>.from(json['assignedStudentIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wardenId': wardenId,
      'wardenName': wardenName,
      'email': email,
      'phone': phone,
      'assignedHostels': assignedHostels,
      'assignedDepartments': assignedDepartments,
      'assignedStudentIds': assignedStudentIds,
    };
  }
}
