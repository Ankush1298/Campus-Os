import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
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
    _activeSession =
        AuthService.instance.currentSession.value ?? _demoPersonas.first;

    // Initialize ERP Leave service
    LeaveService.instance.initialize();
  }

  /// Destinations this role is allowed to see. The screens and the server enforce the same rules,
  /// so hiding a tab here is convenience, not the security boundary.
  List<
    ({
      String label,
      IconData icon,
      IconData selectedIcon,
      Widget Function() build,
    })
  >
  _tabsFor(UserSession s) {
    final student = s.role.toLowerCase() == 'student';
    return [
      if (student)
        (
          label: 'Student Leave',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          build: () => StudentLeaveScreen(session: s),
        ),
      if (!student)
        (
          label: 'Warden Inbox',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield,
          build: () => WardenInboxScreen(session: s),
        ),
      if (!student)
        (
          label: 'Employee ERP',
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge,
          build: () => EmployeeLeaveScreen(session: s),
        ),
      (
        label: 'Academics',
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        build: () => AcademicProfileScreen(session: s),
      ),
    ];
  }

  void _switchPersona(UserSession persona) {
    setState(() {
      _activeSession = persona;
      _currentIndex = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Switched ERP session persona to ${persona.name} (${persona.role.toUpperCase()})',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localOnly = LeaveService.instance.isLocalOnly;
    final tabs = _tabsFor(_activeSession);
    if (_currentIndex >= tabs.length) _currentIndex = 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('ERP & Leave Portal'),
        actions: [
          if (localOnly)
            PopupMenuButton<UserSession>(
              tooltip: 'Switch Demo Persona',
              icon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB3DFE4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
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
                        isCurrent
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 16,
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.textSecondary,
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
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${p.role.toUpperCase()} • ID: ${p.id}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (localOnly)
            IconButton(
              icon: const Icon(
                Icons.restore_page_outlined,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Reset to Demo Seed Data',
              onPressed: () async {
                await LeaveService.instance.resetToSeedData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ERP leave database reset to seed records.',
                      ),
                    ),
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
          // Who is acting + live/demo status, compact and in one glass strip
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              tint: localOnly ? AppColors.warning : AppColors.success,
              tone: GlassTone.tinted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_activeSession.name} (${_activeSession.id})',
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        label: localOnly ? 'DEMO' : 'LIVE',
                        tone: localOnly
                            ? StatusTone.warning
                            : StatusTone.success,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localOnly
                        ? 'Demo mode: leave data is stored on this device only and is not sent to any server.'
                        : 'Leave requests and decisions are saved on the ERP server.',
                    style: AppText.meta,
                  ),
                ],
              ),
            ),
          ),

          // Section switcher (replaces the old second bottom bar: the app already has one)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.sm,
            ),
            child: _SectionTabs(
              labels: [for (final t in tabs) t.label],
              icons: [for (final t in tabs) t.selectedIcon],
              index: _currentIndex,
              onChanged: (i) => setState(() => _currentIndex = i),
            ),
          ),

          // Main View Body
          Expanded(
            child: IndexedStack(
              key: ValueKey(_activeSession.id),
              index: _currentIndex,
              children: [for (final t in tabs) t.build()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented section switcher (glass pill) used inside the ERP portal.
class _SectionTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;
  const _SectionTabs({
    required this.labels,
    required this.icons,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.fast),
                    constraints: const BoxConstraints(
                      minHeight: AppSpacing.touch,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: i == index
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[i],
                            size: 16,
                            color: i == index
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: i == index
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
