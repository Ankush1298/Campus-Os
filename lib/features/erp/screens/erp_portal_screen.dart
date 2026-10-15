import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';
import '../services/leave_service.dart';
import 'academic_profile_screen.dart';
import 'employee_leave_screen.dart';
import 'student_leave_screen.dart';
import 'warden_inbox_screen.dart';

class ErpPortalScreen extends StatefulWidget {
  const ErpPortalScreen({super.key});

  @override
  State<ErpPortalScreen> createState() => _ErpPortalScreenState();
}

class _ErpPortalScreenState extends State<ErpPortalScreen> {
  int _currentIndex = 0;
  late UserSession _activeSession;

  final List<UserSession> _demoPersonas = [
    const UserSession(
      token: 'demo-student-token',
      id: '22CS1042',
      name: 'Aarav Sharma',
      role: 'student',
      isDemo: true,
    ),
    const UserSession(
      token: 'demo-warden-token',
      id: 'FAC-CS-08',
      name: 'Dr. Priya Sen (Warden)',
      role: 'teacher',
      isDemo: true,
    ),
    const UserSession(
      token: 'demo-yamuna-warden-token',
      id: 'WARDEN-YAMUNA',
      name: 'Prof. Rajesh Khanna (Yamuna)',
      role: 'teacher',
      isDemo: true,
    ),
    const UserSession(
      token: 'demo-admin-token',
      id: 'ADMIN01',
      name: 'Campus SuperAdmin',
      role: 'admin',
      isDemo: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Default to currently logged in session or student demo
    _activeSession = AuthService.instance.currentSession.value ?? _demoPersonas.first;

    // Initialize ERP Leave service
    LeaveService.instance.initialize();
  }

  void _switchPersona(UserSession persona) {
    setState(() {
      _activeSession = persona;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched ERP session persona to ${persona.name} (${persona.role.toUpperCase()})'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ERP & Leave Portal'),
        actions: [
          PopupMenuButton<UserSession>(
            tooltip: 'Switch Demo Persona',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _activeSession.role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            onSelected: _switchPersona,
            itemBuilder: (ctx) => _demoPersonas.map((p) {
              final isCurrent = p.id == _activeSession.id;
              return PopupMenuItem<UserSession>(
                value: p,
                child: Row(
                  children: [
                    Icon(
                      isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 16,
                      color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${p.role.toUpperCase()} • ID: ${p.id}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.restore_page_outlined, color: AppColors.textSecondary),
            tooltip: 'Reset to Demo Seed Data',
            onPressed: () async {
              await LeaveService.instance.resetToSeedData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ERP leave database reset to seed records.')),
                );
                setState(() {});
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Active Persona Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active Session: ${_activeSession.name} (${_activeSession.id})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge.role(_activeSession.role),
              ],
            ),
          ),

          // Main View Body
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                StudentLeaveScreen(session: _activeSession),
                WardenInboxScreen(session: _activeSession),
                EmployeeLeaveScreen(session: _activeSession),
                AcademicProfileScreen(session: _activeSession),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE0E7FF),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
              label: 'Student Leave',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield, color: AppColors.primary),
              label: 'Warden Inbox',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge, color: AppColors.primary),
              label: 'Employee ERP',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school, color: AppColors.primary),
              label: 'Academics',
            ),
          ],
        ),
      ),
    );
  }
}
