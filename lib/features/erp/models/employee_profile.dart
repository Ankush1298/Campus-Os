class EmployeeProfile {
  final String id;
  final String name;
  final String department;
  final String designation;
  final String email;
  final String phone;
  final String status; // 'Active', 'On Leave'
  final String? reportingManager;
  final Map<String, int>
  leaveBalance; // e.g. {'Casual': 12, 'Sick': 8, 'Earned': 15}

  const EmployeeProfile({
    required this.id,
    required this.name,
    required this.department,
    required this.designation,
    required this.email,
    required this.phone,
    this.status = 'Active',
    this.reportingManager,
    this.leaveBalance = const {'Casual': 12, 'Sick': 8, 'Earned': 15},
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    final rawBalance = json['leaveBalance'] as Map<String, dynamic>? ?? {};
    return EmployeeProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      reportingManager: json['reportingManager'] as String?,
      leaveBalance: rawBalance.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'designation': designation,
      'email': email,
      'phone': phone,
      'status': status,
      'reportingManager': reportingManager,
      'leaveBalance': leaveBalance,
    };
  }
}
