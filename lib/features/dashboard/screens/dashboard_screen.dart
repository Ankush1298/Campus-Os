import 'package:flutter/material.dart';

import '../../../core/branding/campus_logo.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../attendance/services/attendance_service.dart';
import '../../attendance/widgets/qr_scanner_sheet.dart';
import '../../auth/models/user_session.dart';
import '../../shell/app_shell.dart';
import 'profile_sheet.dart';

/// Home tab: who you are, what is on today, what you do most, and every module.
/// Real data for live sessions (clear loading / empty / error states); demo sessions are labelled as demo.
class DashboardScreen extends StatefulWidget {
  final UserSession session;
  final void Function(ShellTab tab)? onNavigate;

  const DashboardScreen({super.key, required this.session, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _LoadState { loading, ready, error }

class _DashboardScreenState extends State<DashboardScreen> {
  _LoadState _state = _LoadState.loading;
  String? _error;
  List<Map<String, dynamic>> _today = [];
  double? _percent;

  UserSession get _s => widget.session;
  bool get _hasSchedule => _s.isStudent || _s.isTeacher;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  Future<void> _load() async {
    if (!_hasSchedule) {
      setState(() => _state = _LoadState.ready);
      return;
    }
    setState(() {
      _state = _LoadState.loading;
      _error = null;
    });
    try {
      final svc = AttendanceService.instance;
      final res = _s.isStudent
          ? await svc.fetchStudentTimetable(isDemo: _s.isDemo)
          : await svc.fetchTeacherTimetable(isDemo: _s.isDemo);
      final today = _days[DateTime.now().weekday - 1];
      final items =
          ((res['items'] as List?) ?? const [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .where(
                (m) =>
                    _s.isDemo ||
                    m['day_of_week'] == null ||
                    m['day_of_week'].toString().toLowerCase() == today,
              )
              .toList()
            ..sort(
              (a, b) => '${a['start_time']}'.compareTo('${b['start_time']}'),
            );
      double? pct;
      if (_s.isStudent) {
        try {
          final o = await svc.fetchOverview(_s);
          final sum = (o['summary'] ?? o['my_attendance']) as Map?;
          final v = sum?['percentage'] ?? sum?['overall_percent'];
          if (v is num) pct = v.toDouble();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _today = items;
        _percent = pct;
        _state = _LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _error = e is ApiException
            ? (e.statusCode == 404
                  ? 'The attendance server does not have the timetable service yet (HTTP 404).'
                  : e.message)
            : e.toString();
      });
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12
        ? 'Good morning'
        : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  void _go(ShellTab t) => widget.onNavigate?.call(t);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ResponsiveBody(
        child: Column(
          children: [
            // Pinned brand bar: logo + profile stay reachable while the page scrolls.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                0,
              ),
              child: _header(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.lg,
                  ),
                  children: [
                    _greetingBlock(),
                    if (_hasSchedule || _s.isDemo) ...[
                      const SizedBox(height: AppSpacing.md),
                      _todayCard(),
                    ],
                    const SectionHeader(title: 'Quick actions'),
                    _quickActions(context),
                    const SectionHeader(title: 'Academics'),
                    _academics(),
                    const SectionHeader(title: 'Campus services'),
                    _services(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CampusLogo(markSize: 34),
          ),
        ),
        Semantics(
          button: true,
          label: 'Profile and sign out',
          child: InkWell(
            key: const Key('open-profile'),
            customBorder: const CircleBorder(),
            onTap: () => showProfileSheet(context, _s),
            child: Container(
              width: AppSpacing.touch,
              height: AppSpacing.touch,
              alignment: Alignment.center,
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.midnight,
                child: Text(
                  _s.name.isNotEmpty ? _s.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _greetingBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(), style: AppText.meta),
        const SizedBox(height: 2),
        Text(
          _s.name,
          style: AppText.display.copyWith(fontSize: 26),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge.role(_s.role),
            Text('ID: ${_s.id}', style: AppText.meta),
            if (_s.isDemo)
              const StatusChip(
                label: 'DEMO MODE',
                tone: StatusTone.warning,
                icon: Icons.science_outlined,
                dense: true,
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- today
  Widget _todayCard() {
    return GlassCard(
      blur: true,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.today_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Today', style: AppText.heading)),
              if (_percent != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_percent!.toStringAsFixed(1)}%',
                          style: AppText.stat.copyWith(
                            fontSize: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('attendance', style: AppText.meta),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: AppMotion.of(context),
            child: _todayBody(),
          ),
          if (_s.isDemo)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Sample data for demonstration. Sign in with a real account to see your own schedule.',
                style: AppText.meta,
              ),
            ),
        ],
      ),
    );
  }

  Widget _todayBody() {
    switch (_state) {
      case _LoadState.loading:
        return Column(
          key: const ValueKey('loading'),
          children: [for (var i = 0; i < 2; i++) _skeletonRow()],
        );
      case _LoadState.error:
        return Column(
          key: const ValueKey('error'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Couldn't load today's schedule. ${_error ?? ''}",
                    style: AppText.bodySecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        );
      case _LoadState.ready:
        if (!_hasSchedule) {
          return const Text(
            'Administrators manage timetables and rooms from the Attendance tab.',
            key: ValueKey('admin'),
            style: AppText.bodySecondary,
          );
        }
        if (_today.isEmpty) {
          return const Row(
            key: ValueKey('empty'),
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No classes scheduled for today.',
                  style: AppText.bodySecondary,
                ),
              ),
            ],
          );
        }
        return Column(
          key: const ValueKey('list'),
          children: [
            for (final c in _today.take(3)) _classRow(c),
            if (_today.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _go(ShellTab.attendance),
                  child: Text('See all ${_today.length} classes'),
                ),
              ),
          ],
        );
    }
  }

  Widget _skeletonRow() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 56,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _classRow(Map<String, dynamic> c) {
    final subject = '${c['subject'] ?? c['course_name'] ?? 'Class'}';
    final time = c['start_time'] != null ? '${c['start_time']}' : '';
    final room = '${c['room_id'] ?? c['room_number'] ?? ''}';
    final phase = c['active_phase']?.toString();
    String status = '${c['attendance_status'] ?? ''}';
    StatusChip chip;
    if (phase != null && ((c['remaining_seconds'] as num?) ?? 0) > 0) {
      chip = StatusChip(
        label: '${phase.toUpperCase()} OPEN',
        tone: StatusTone.warning,
        icon: Icons.timer_outlined,
        dense: true,
      );
    } else {
      switch (status) {
        case 'present':
          chip = const StatusChip(
            label: 'PRESENT',
            tone: StatusTone.success,
            dense: true,
          );
        case 'absent':
          chip = const StatusChip(
            label: 'ABSENT',
            tone: StatusTone.error,
            dense: true,
          );
        case 'pending':
          chip = const StatusChip(
            label: 'AWAITING END',
            tone: StatusTone.warning,
            dense: true,
          );
        default:
          chip = const StatusChip(
            label: 'SCHEDULED',
            tone: StatusTone.neutral,
            dense: true,
          );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 240;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      time,
                      style: AppText.label.copyWith(
                        color: AppColors.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    chip,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subject,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (room.isNotEmpty)
                  Text(
                    room,
                    style: AppText.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: 54,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    time,
                    style: AppText.label.copyWith(
                      color: AppColors.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (room.isNotEmpty)
                      Text(
                        room,
                        style: AppText.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: chip,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- quick actions
  Widget _quickActions(BuildContext context) {
    final actions = <_Quick>[
      if (_s.isStudent)
        _Quick(
          Icons.qr_code_scanner_rounded,
          'Scan class QR',
          () => QrScannerSheet.show(
            context,
            session: _s,
            onAttendanceMarked: _load,
          ),
        ),
      if (_s.isTeacher)
        _Quick(
          Icons.play_circle_outline_rounded,
          'Start attendance',
          () => _go(ShellTab.attendance),
        ),
      if (_s.isAdmin)
        _Quick(
          Icons.upload_file_rounded,
          'Upload timetable',
          () => _go(ShellTab.attendance),
        ),
      _Quick(
        _s.isStudent ? Icons.event_note_outlined : Icons.fact_check_outlined,
        _s.isStudent ? 'Apply for leave' : 'Leave approvals',
        () => _go(ShellTab.campus),
      ),
      _Quick(
        Icons.photo_camera_outlined,
        'GeoCam capture',
        () => _go(ShellTab.capture),
      ),
      _Quick(Icons.science_outlined, 'Practice', () => _go(ShellTab.learn)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * AppSpacing.sm) / cols;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final a in actions)
              SizedBox(
                width: w,
                child: GlassCard(
                  onTap: a.onTap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  semanticLabel: a.label,
                  child: Row(
                    children: [
                      Icon(a.icon, size: 22, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.label,
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- modules
  Widget _academics() => Column(
    children: [
      ModuleCard(
        title: 'Smart Attendance System',
        subtitle: _s.isStudent
            ? 'Scan the classroom QR, see your timetable and attendance.'
            : (_s.isTeacher
                  ? 'Start and end class attendance, review results.'
                  : 'Timetable upload, rooms and attendance reports.'),
        icon: Icons.how_to_reg_rounded,
        badgeText: _s.isDemo ? 'DEMO' : 'LIVE',
        onTap: () => _go(ShellTab.attendance),
      ),
      const SizedBox(height: AppSpacing.sm),
      ModuleCard(
        title: 'PractiVerse Labs',
        subtitle: 'Guided physics, maths, chemistry and coding practicals.',
        icon: Icons.science_rounded,
        iconColor: AppColors.accent,
        iconBgColor: const Color(0xFFE8EBFF),
        onTap: () => _go(ShellTab.learn),
      ),
    ],
  );

  Widget _services() => Column(
    children: [
      ModuleCard(
        title: 'ERP & Leave Management',
        subtitle: _s.isStudent
            ? 'Apply for leave and follow decisions from your warden.'
            : 'Review leave requests, apply for your own leave, staff directory.',
        icon: Icons.apartment_rounded,
        onTap: () => _go(ShellTab.campus),
      ),
      const SizedBox(height: AppSpacing.sm),
      ModuleCard(
        title: 'GeoCam Camera Module',
        subtitle: 'Location-verified photos with a QR anyone can check.',
        icon: Icons.photo_camera_rounded,
        iconColor: AppColors.info,
        iconBgColor: const Color(0xFFE5F2FB),
        onTap: () => _go(ShellTab.capture),
      ),
    ],
  );
}

class _Quick {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _Quick(this.icon, this.label, this.onTap);
}
