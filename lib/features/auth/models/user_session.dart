class UserSession {
  final String token;
  final String id;
  final String name;
  final String role; // student, teacher, admin
  final int? expiresAt;
  final bool isDemo;

  const UserSession({
    required this.token,
    required this.id,
    required this.name,
    required this.role,
    this.expiresAt,
    this.isDemo = false,
  });

  bool get isStudent => role.toLowerCase() == 'student';
  bool get isTeacher => role.toLowerCase() == 'teacher' || role.toLowerCase() == 'faculty';
  bool get isAdmin => role.toLowerCase() == 'admin';

  bool get isExpired {
    if (expiresAt == null || isDemo) return false;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt! <= nowSeconds;
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      token: json['token'] as String? ?? '',
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Campus User',
      role: json['role'] as String? ?? 'student',
      expiresAt: json['expires_at'] as int?,
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'id': id,
      'name': name,
      'role': role,
      'expires_at': expiresAt,
      'is_demo': isDemo,
    };
  }

  static UserSession demoStudent() {
    return const UserSession(
      token: 'demo-student-token-campusos-2026',
      id: '22CS1042',
      name: 'Aarav Sharma',
      role: 'student',
      isDemo: true,
    );
  }

  static UserSession demoFaculty() {
    return const UserSession(
      token: 'demo-faculty-token-campusos-2026',
      id: 'FAC-CS-08',
      name: 'Dr. Priya Sen',
      role: 'teacher',
      isDemo: true,
    );
  }

  static UserSession demoAdmin() {
    return const UserSession(
      token: 'demo-admin-token-campusos-2026',
      id: 'ADMIN01',
      name: 'Campus SuperAdmin',
      role: 'admin',
      isDemo: true,
    );
  }
}
