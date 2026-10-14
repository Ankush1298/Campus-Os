import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../attendance/screens/attendance_screen.dart';
import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';
import '../../erp/erp_module.dart';
import '../../geocam/screens/geocam_screen.dart';
import '../../practiverse/practiverse_module.dart';

class DashboardScreen extends StatelessWidget {
  final UserSession session;

  const DashboardScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'CampusOS',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          StatusBadge.role(session.role),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Greeting & Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        session.name.isNotEmpty ? session.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            session.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'ID: ${session.id} ${session.isDemo ? "• Demo Mode" : ""}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Quick Campus Status Row
          Row(
            children: [
              Expanded(
                child: _buildQuickMetric(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  title: 'Attendance',
                  value: '87.5%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickMetric(
                  icon: Icons.location_on_outlined,
                  color: AppColors.info,
                  title: 'Geofence',
                  value: 'Zone A',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickMetric(
                  icon: Icons.schedule_outlined,
                  color: AppColors.primaryLight,
                  title: 'Next Class',
                  value: '02:00 PM',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Modules Section Title
          const Text(
            'CampusOS Modules',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Module 1: Smart Attendance System
          ModuleCard(
            title: 'Smart Attendance System',
            subtitle: 'AI face recognition, real-time timetable, and attendance reports',
            icon: Icons.how_to_reg_rounded,
            iconColor: AppColors.primary,
            iconBgColor: const Color(0xFFEFF6FF),
            badgeText: 'CONNECTED',
            badgeColor: AppColors.success,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              );
            },
          ),
          const SizedBox(height: 12),

          // Module 2: GeoCam
          ModuleCard(
            title: 'GeoCam Camera Module',
            subtitle: 'Tamper-proof photo verification with GPS & cryptographic stamps',
            icon: Icons.camera_alt_rounded,
            iconColor: AppColors.accent,
            iconBgColor: const Color(0xFFF0FDFA),
            badgeText: 'INTEGRATED',
            badgeColor: AppColors.accent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GeoCamScreen()),
              );
            },
          ),
          const SizedBox(height: 12),

          // Module 3: ERP & Leave Portal (Person 2)
          ModuleCard(
            title: 'ERP & Leave Management',
            subtitle: 'Owned by Person 2 • Branch: feature/erp-leave',
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFFD97706),
            iconBgColor: const Color(0xFFFFFBEB),
            badgeText: 'PERSON 2 MODULE',
            badgeColor: const Color(0xFFD97706),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ErpModule.getEntryPoint(context)),
              );
            },
          ),
          const SizedBox(height: 12),

          // Module 4: PractiVerse (Person 3)
          ModuleCard(
            title: 'PractiVerse Labs',
            subtitle: 'Owned by Person 3 • Branch: feature/practiverse',
            icon: Icons.science_outlined,
            iconColor: const Color(0xFF4F46E5),
            iconBgColor: const Color(0xFFEEF2FF),
            badgeText: 'PERSON 3 MODULE',
            badgeColor: const Color(0xFF4F46E5),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PractiverseModule.getEntryPoint(context)),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Hackathon Integration Notice
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.code_rounded, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'CampusOS Core Foundation v1.0 • Ready for Person 2 & Person 3 branch merges',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetric({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to end your current CampusOS session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.instance.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(80, 36),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
