import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';
import '../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  bool _isServerHealthy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final session = AuthService.instance.currentSession.value;
    if (session == null) {
      setState(() {
        _errorMessage = 'No active session found. Please log in.';
        _isLoading = false;
      });
      return;
    }

    try {
      final healthy = await AttendanceService.instance.checkHealth();
      final overview = await AttendanceService.instance.fetchOverview(session);
      if (mounted) {
        setState(() {
          _isServerHealthy = healthy;
          _data = overview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.instance.currentSession.value ?? UserSession.demoStudent();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(session),
    );
  }

  Widget _buildBody(UserSession session) {
    if (_isLoading) {
      return const LoadingView(message: 'Connecting to Attendance Engine...');
    }

    if (_errorMessage != null) {
      return ErrorStateView(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    final summary = _data?['summary'] as Map<String, dynamic>?;
    final profile = _data?['profile'] as Map<String, dynamic>?;
    final todayRaw = _data?['today'];
    final List<dynamic> todaySlots;
    if (todayRaw is List) {
      todaySlots = todayRaw;
    } else if (todayRaw is Map && todayRaw['items'] is List) {
      todaySlots = todayRaw['items'] as List<dynamic>;
    } else {
      todaySlots = [];
    }

    final isDemo = session.isDemo;
    final bannerColor = isDemo
        ? const Color(0xFFEFF6FF)
        : (_isServerHealthy ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7));
    final borderColor = isDemo
        ? const Color(0xFFBFDBFE)
        : (_isServerHealthy ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A));
    final iconColor = isDemo
        ? AppColors.primary
        : (_isServerHealthy ? const Color(0xFF059669) : const Color(0xFFD97706));
    final textColor = isDemo
        ? const Color(0xFF1E40AF)
        : (_isServerHealthy ? const Color(0xFF065F46) : const Color(0xFF92400E));
    final bannerText = isDemo
        ? 'Demo Mode — Displaying local simulated session data'
        : (_isServerHealthy
            ? 'Connected to Live Smart Attendance System'
            : 'Live Server Unreachable (${ApiClient.baseUrl})');

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Server connectivity status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  isDemo
                      ? Icons.bolt_rounded
                      : (_isServerHealthy ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bannerText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Overview KPI Card
          if (summary != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ATTENDANCE RATE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          summary['status'] ?? 'Good Standing',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${summary['percentage'] ?? summary['overall_percent'] ?? 0}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${summary['attended'] ?? summary['present'] ?? 0} of ${summary['total_classes'] ?? summary['classes_counted'] ?? 0} classes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (((summary['percentage'] ?? summary['overall_percent']) as num?)?.toDouble() ?? 0) / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Face KYC / Biometric Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Facial Biometric Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (profile?['face_registered'] == true)
                            ? 'Face profile active & verified for camera check-in'
                            : 'Face capture required for AI attendance',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.status(profile?['face_registered'] == true ? 'READY' : 'PENDING'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Today's Class Schedule Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Schedule",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${todaySlots.length} sessions',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (todaySlots.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No sessions scheduled for today.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...todaySlots.map((slot) {
              final course = slot['course'] ?? slot['subject'] ?? 'Class Session';
              final time = slot['slot'] ??
                  (slot['start_time'] != null && slot['end_time'] != null
                      ? '${slot['start_time']} - ${slot['end_time']}'
                      : '');
              final room = slot['room'] ?? slot['room_id'] ?? '';
              final status = slot['status'] ?? 'Scheduled';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: status == 'Present' ? AppColors.success : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.meeting_room_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                room,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    StatusBadge.status(status),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
