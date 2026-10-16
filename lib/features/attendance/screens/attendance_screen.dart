import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';
import '../../geocam/screens/geocam_screen.dart';
import '../services/attendance_service.dart';
import '../widgets/admin_timetable_draft_sheet.dart';
import '../widgets/qr_scanner_sheet.dart';
import 'face_registration_webview_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _overviewData;
  List<Map<String, dynamic>> _historyData = [];
  List<Map<String, dynamic>> _camerasData = [];
  List<Map<String, dynamic>> _timetableData = [];
  List<Map<String, dynamic>> _studentTimetableSlots = [];
  List<Map<String, dynamic>> _teacherTimetableSlots = [];
  // Why the QR timetable could not be loaded (null = loaded, or not applicable). Never swallowed silently.
  String? _timetableError;
  DateTime _slotsFetchedAt = DateTime.now();
  Timer? _ticker;
  bool _isOperatingQr = false;
  bool _isServerHealthy = false;

  @override
  void initState() {
    super.initState();
    final session =
        AuthService.instance.currentSession.value ?? UserSession.demoStudent();
    final tabCount = session.isAdmin ? 3 : 2; // Student: Overview + History; Faculty: Overview + Sessions; Admin: Overview + Cameras + Timetable
    _tabController = TabController(length: tabCount, vsync: this);
    _loadAllData();
    // Drives the countdown and refreshes the class state while a QR window is open.
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final live = _hasLiveWindow();
      if (live && t.tick % 8 == 0 && !_isLoading) {
        _loadAllData(silent: true);
      } else if (live) {
        setState(() {});
      }
    });
  }

  bool _hasLiveWindow() => [
    ..._studentTimetableSlots,
    ..._teacherTimetableSlots,
  ].any((s) => s['active_phase'] != null && _remainingFor(s) > 0);

  int _remainingFor(Map<String, dynamic> slot) {
    final base = (slot['remaining_seconds'] as num?)?.toInt() ?? 0;
    return base - DateTime.now().difference(_slotsFetchedAt).inSeconds;
  }

  String _mmss(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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

      List<Map<String, dynamic>> history = [];
      List<Map<String, dynamic>> cameras = [];
      List<Map<String, dynamic>> timetable = [];
      List<Map<String, dynamic>> studentSlots = [];
      List<Map<String, dynamic>> teacherSlots = [];

      String? ttError;
      String describe(Object e) => e is ApiException
          ? (e.statusCode == 404
                ? 'This server does not have the QR attendance routes yet (HTTP 404). The updated Smart Attendance backend must be deployed.'
                : e.message)
          : e.toString();
      if (session.isStudent) {
        try {
          history = await AttendanceService.instance.fetchStudentHistory(
            session,
          );
        } catch (_) {}
        try {
          final res = await AttendanceService.instance.fetchStudentTimetable(
            isDemo: session.isDemo,
          );
          final items = res['items'] as List<dynamic>? ?? [];
          studentSlots = items
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } catch (e) {
          ttError = describe(e);
        }
      } else if (session.isTeacher) {
        try {
          final res = await AttendanceService.instance.fetchTeacherTimetable(
            isDemo: session.isDemo,
          );
          final items = res['items'] as List<dynamic>? ?? [];
          teacherSlots = items
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } catch (e) {
          ttError = describe(e);
        }
      } else if (session.isAdmin) {
        try {
          cameras = await AttendanceService.instance.fetchCameras();
          timetable = await AttendanceService.instance.fetchTimetable();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isServerHealthy = healthy;
          _overviewData = overview;
          _historyData = history;
          _camerasData = cameras;
          _timetableData = timetable;
          _studentTimetableSlots = studentSlots;
          _teacherTimetableSlots = teacherSlots;
          _timetableError = ttError;
          _slotsFetchedAt = DateTime.now();
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

  Future<void> _uploadTimetable() async {
    final session = AuthService.instance.currentSession.value;
    if (session == null || _isOperatingQr) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'xlsx',
          'xls',
          'csv',
          'docx',
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _isOperatingQr = true);
      final res = await AttendanceService.instance.uploadTimetable(
        bytes: bytes,
        filename: file.name,
        isDemo: session.isDemo,
      );
      final draftId = res['draft_id']?.toString();
      if (!mounted) return;
      if (draftId == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Upload finished but no draft was returned.'),
          ),
        );
        return;
      }
      await AdminTimetableDraftSheet.show(
        context,
        draftId: draftId,
        onPublished: _loadAllData,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Timetable upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOperatingQr = false);
    }
  }

  Future<void> _startAttendance(int slotId) async {
    final session = AuthService.instance.currentSession.value;
    if (session == null || _isOperatingQr) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Attendance Session?'),
        content: const Text(
          'This initiates a 5-minute Start Attendance window on the classroom display. Students must scan before the timer expires.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Start (5m)'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isOperatingQr = true);
    try {
      final res = await AttendanceService.instance.startQrAttendance(
        timetableId: slotId,
        isDemo: session.isDemo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message'] ??
                  'Start attendance session active! (5m remaining)',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start attendance: ${e is ApiException ? e.message : e}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOperatingQr = false);
    }
  }

  Future<void> _endAttendance(int slotId) async {
    final session = AuthService.instance.currentSession.value;
    if (session == null || _isOperatingQr) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Class Attendance?'),
        content: const Text(
          'This invalidates the Start token and starts a 5-minute End Attendance window. Students must scan again to confirm attendance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Start End Phase (5m)'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isOperatingQr = true);
    try {
      final res = await AttendanceService.instance.endQrAttendance(
        timetableId: slotId,
        isDemo: session.isDemo,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message'] ?? 'End attendance phase active! (5m remaining)',
            ),
            backgroundColor: AppColors.accent,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to end attendance: ${e is ApiException ? e.message : e}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOperatingQr = false);
    }
  }

  void _showFaceRegistrationDialog() async {
    final session =
        AuthService.instance.currentSession.value ?? UserSession.demoStudent();
    final regInfo = await AttendanceService.instance.fetchRegistrationInfo();
    final role = session.isTeacher ? 'teacher' : 'student';
    final targetUrl = role == 'teacher'
        ? (regInfo['teacher_url'] ??
              'https://attendance-register-production.up.railway.app/teacher')
        : (regInfo['student_url'] ??
              'https://attendance-register-production.up.railway.app/student');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${session.isTeacher ? 'Faculty' : 'Student'} Face KYC Enrollment',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Pre-linked Account: ${session.id} (${session.name})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live 3D KYC Requirements:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '1. Ensure good frontal lighting without strong backlights.',
                    ),
                    const Text(
                      '2. Hold device at eye level and follow audio cues to turn slowly.',
                    ),
                    const Text(
                      '3. Use your admin passcode provided for biometric enrollment.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registration Host: $targetUrl',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FaceRegistrationWebViewScreen(
                          url: targetUrl,
                          session: session,
                        ),
                      ),
                    ).then((_) => _loadAllData());
                  },
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Launch In-App Enrollment'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTeacherOverrideDialog(String sessionId) {
    final rollCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String newStatus = 'present';
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Manual Override: $sessionId'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Correct attendance for a student in this session. All changes are audited.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: rollCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Student Roll No / ID',
                      hintText: 'e.g. 21CS001',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: newStatus,
                    decoration: const InputDecoration(
                      labelText: 'New Status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'present',
                        child: Text('Present'),
                      ),
                      DropdownMenuItem(value: 'absent', child: Text('Absent')),
                      DropdownMenuItem(value: 'late', child: Text('Late')),
                      DropdownMenuItem(
                        value: 'excused',
                        child: Text('Excused'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => newStatus = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Audit Reason',
                      hintText:
                          'e.g. Approved medical leave or camera obstruction',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter your faculty password',
                      isDense: true,
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (rollCtrl.text.trim().isEmpty ||
                            reasonCtrl.text.trim().isEmpty ||
                            passCtrl.text.isEmpty) {
                          setDialogState(
                            () => dialogError =
                                'Please fill all required fields.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });

                        try {
                          await AttendanceService.instance
                              .submitTeacherOverride(
                                sessionId: sessionId,
                                rollNo: rollCtrl.text.trim(),
                                newStatus: newStatus,
                                password: passCtrl.text,
                                reason: reasonCtrl.text.trim(),
                              );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Attendance override recorded successfully.',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _loadAllData();
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            dialogError = e.toString().replaceFirst(
                              'ApiException: ',
                              '',
                            );
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Apply Override'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _inspectTeacherSession(String sessionId) async {
    final session =
        AuthService.instance.currentSession.value ?? UserSession.demoFaculty();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: AttendanceService.instance.fetchTeacherSession(
            sessionId,
            session,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 250,
                child: Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final sessInfo = data['session'] as Map<String, dynamic>? ?? {};
            final studentsRaw = data['students'];
            final List<dynamic> studentsList = studentsRaw is List
                ? studentsRaw
                : [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Session: ${sessInfo['course_name'] ?? sessionId}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Room: ${sessInfo['room_number'] ?? 'N/A'} • Section: ${sessInfo['section'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Student Roster (${studentsList.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showTeacherOverrideDialog(sessionId);
                        },
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('Override Student'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: studentsList.isEmpty
                        ? const Center(
                            child: Text(
                              'No student records found for this session.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: studentsList.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final st =
                                  studentsList[idx] as Map<String, dynamic>;
                              final status = st['status'] ?? 'unknown';
                              final isPresent =
                                  status.toString().toLowerCase() == 'present';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isPresent
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.error.withValues(alpha: 0.1),
                                  child: Icon(
                                    isPresent ? Icons.check : Icons.close,
                                    size: 16,
                                    color: isPresent
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                                title: Text(
                                  st['name'] ?? st['roll_no'] ?? 'Student',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Roll: ${st['roll_no']} • ${st['minutes'] ?? 0}m detected',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: StatusBadge.status(status),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session =
        AuthService.instance.currentSession.value ?? UserSession.demoStudent();

    String tab2Title = 'History';
    IconData tab2Icon = Icons.history_rounded;
    if (session.isTeacher) {
      tab2Title = 'Sessions';
      tab2Icon = Icons.calendar_month_outlined;
    } else if (session.isAdmin) {
      tab2Title = 'Cameras';
      tab2Icon = Icons.videocam_outlined;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(tab2Icon), text: tab2Title),
            if (session.isAdmin)
              const Tab(
                icon: Icon(Icons.table_chart_outlined),
                text: 'Timetable',
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded),
            tooltip: 'In-App Camera',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GeoCamScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: 'Connecting to Attendance Engine...')
          : _errorMessage != null
          ? ErrorStateView(message: _errorMessage!, onRetry: _loadAllData)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(session),
                if (session.isStudent)
                  _buildStudentHistoryTab()
                else if (session.isTeacher)
                  _buildTeacherSessionsTab()
                else ...[
                  _buildAdminCamerasTab(),
                  _buildAdminTimetableTab(),
                ],
              ],
            ),
    );
  }

  Widget _buildOverviewTab(UserSession session) {
    final summary =
        (_overviewData?['summary'] ?? _overviewData?['my_attendance'])
            as Map<String, dynamic>?;
    final profile = _overviewData?['profile'] as Map<String, dynamic>?;
    final List<dynamic> todaySlots;
    final dayName = const [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ][DateTime.now().weekday - 1];
    bool isToday(Map<String, dynamic> s) =>
        session.isDemo ||
        s['day_of_week'] == null ||
        s['day_of_week'].toString().toLowerCase() == dayName;
    if (session.isStudent && _studentTimetableSlots.isNotEmpty) {
      todaySlots = _studentTimetableSlots.where(isToday).toList();
    } else if (session.isTeacher && _teacherTimetableSlots.isNotEmpty) {
      todaySlots = _teacherTimetableSlots.where(isToday).toList();
    } else {
      final todayRaw = _overviewData?['today'];
      if (todayRaw is List) {
        todaySlots = todayRaw;
      } else if (todayRaw is Map && todayRaw['items'] is List) {
        todaySlots = todayRaw['items'] as List<dynamic>;
      } else {
        todaySlots = [];
      }
    }

    final isDemo = session.isDemo;
    final bannerColor = isDemo
        ? const Color(0xFFE6F4F5)
        : (_isServerHealthy
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFEF3C7));
    final borderColor = isDemo
        ? const Color(0xFFB3DFE4)
        : (_isServerHealthy
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFFDE68A));
    final iconColor = isDemo
        ? AppColors.primary
        : (_isServerHealthy
              ? const Color(0xFF059669)
              : const Color(0xFFD97706));
    final textColor = isDemo
        ? const Color(0xFF0B5F68)
        : (_isServerHealthy
              ? const Color(0xFF065F46)
              : const Color(0xFF92400E));
    final bannerText = isDemo
        ? 'Demo Mode — Displaying local simulated session data'
        : (_isServerHealthy
              ? 'Connected to Live Smart Attendance System (${ApiClient.baseUrl})'
              : 'Live Server Unreachable (${ApiClient.baseUrl})');

    final percentageNum =
        summary?['percentage'] ??
        summary?['overall_percent'] ??
        summary?['average_attendance'] ??
        0;
    final totalCount =
        summary?['total_classes'] ??
        summary?['classes_counted'] ??
        summary?['classes_conducted'] ??
        0;
    final subText = session.isTeacher
        ? '$totalCount lectures conducted'
        : '${summary?['attended'] ?? summary?['present'] ?? 0} of $totalCount classes';
    final kpiTitle = session.isTeacher
        ? 'FACULTY AVERAGE PRESENCE'
        : 'ATTENDANCE RATE';

    return RefreshIndicator(
      onRefresh: _loadAllData,
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
                      : (_isServerHealthy
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded),
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        kpiTitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          summary['status'] ??
                              (percentageNum >= 75
                                  ? 'Good Standing'
                                  : 'Active'),
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 12,
                    children: [
                      Text(
                        '$percentageNum%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Profile & Face Registration Card
          if (profile != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryLight.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primaryLight,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['name'] ?? session.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${profile['id'] ?? session.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showFaceRegistrationDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (profile['face_registered'] == true)
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (profile['face_registered'] == true)
                                ? Icons.verified_user_rounded
                                : Icons.warning_amber_rounded,
                            size: 14,
                            color: (profile['face_registered'] == true)
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (profile['face_registered'] == true)
                                ? 'KYC Enrolled'
                                : 'KYC Pending',
                            style: TextStyle(
                              color: (profile['face_registered'] == true)
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _showFaceRegistrationDialog,
            icon: const Icon(Icons.face_retouching_natural_rounded, size: 18),
            label: const Text('Biometric KYC & Face Registration'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Today's Timetable Section
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

          if (_timetableError != null &&
              !session.isDemo &&
              (session.isStudent || session.isTeacher))
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'QR attendance timetable unavailable: $_timetableError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (todaySlots.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
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
              final slotId =
                  (slot['id'] ?? slot['timetable_id'] ?? slot['slot_id'] ?? 0)
                      is int
                  ? (slot['id'] ?? slot['timetable_id'] ?? slot['slot_id'] ?? 0)
                        as int
                  : int.tryParse(
                          '${slot['id'] ?? slot['timetable_id'] ?? slot['slot_id'] ?? 0}',
                        ) ??
                        0;
              final course =
                  slot['course'] ??
                  slot['course_name'] ??
                  slot['subject'] ??
                  'Class Session';
              final time =
                  slot['slot'] ??
                  (slot['start_time'] != null && slot['end_time'] != null
                      ? '${slot['start_time']} - ${slot['end_time']}'
                      : '');
              final room =
                  slot['room'] ?? slot['room_number'] ?? slot['room_id'] ?? '';
              final teacher = slot['teacher_name'] ?? slot['faculty'] ?? '';
              final section = slot['section_id'] ?? slot['section'] ?? '';
              final startConfirmed =
                  slot['start_confirmed'] == true ||
                  slot['start_scanned'] == true;
              final endConfirmed =
                  slot['end_confirmed'] == true || slot['end_scanned'] == true;
              final activePhase = slot['active_phase']?.toString();
              final remaining = activePhase == null
                  ? 0
                  : _remainingFor(Map<String, dynamic>.from(slot as Map));
              final windowOpen = activePhase != null && remaining > 0;
              final finalized = slot['finalized'] == true;
              final rawStatus =
                  slot['status'] ??
                  const {
                    'present': 'Present',
                    'absent': 'Absent',
                    'pending': 'Pending End',
                    'unmeasurable': 'Unmeasurable',
                    'warning': 'Warning',
                  }[slot['attendance_status']?.toString()];
              final status =
                  rawStatus ??
                  ((startConfirmed && endConfirmed)
                      ? 'Present'
                      : (startConfirmed ? 'Pending End' : 'Scheduled'));

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 52,
                          decoration: BoxDecoration(
                            color:
                                (startConfirmed && endConfirmed) ||
                                    status == 'Present'
                                ? AppColors.success
                                : (startConfirmed
                                      ? AppColors.warning
                                      : AppColors.primaryLight),
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
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  if (time.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (room.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.meeting_room_outlined,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          room,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (section.isNotEmpty)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.group_outlined,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Sec $section',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (teacher.isNotEmpty && session.isStudent)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          teacher,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        StatusBadge.status(status.toString()),
                      ],
                    ),

                    // Two-phase attendance status indicator chips
                    if (session.isStudent) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      if (windowOpen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${activePhase.toUpperCase()} attendance is OPEN, scan the classroom QR within ${_mmss(remaining)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          _buildPhaseChip('Start (0-5m)', startConfirmed),
                          const SizedBox(width: 8),
                          _buildPhaseChip('End (Last 5m)', endConfirmed),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => QrScannerSheet.show(
                              context,
                              session: session,
                              onAttendanceMarked: _loadAllData,
                            ),
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Scan QR',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Teacher live controls
                    if (session.isTeacher && slotId > 0) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      if (slot['can_start'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            finalized
                                ? 'Finalised: ${slot['start_scans_count'] ?? 0} scanned Start, ${slot['end_scans_count'] ?? 0} scanned End.'
                                : windowOpen
                                ? '${activePhase.toUpperCase()} window open, ${_mmss(remaining)} left. ${activePhase == 'start' ? slot['start_scans_count'] : slot['end_scans_count']} scanned so far.'
                                : (slot['start_scans_count'] ?? 0) > 0 ||
                                      (slot['end_scans_count'] ?? 0) > 0
                                ? 'Window closed. Start scans: ${slot['start_scans_count']}, End scans: ${slot['end_scans_count']}.'
                                : 'Not started. Start opens a ${_mmss(300)} QR window on the classroom display.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isOperatingQr || slot['can_start'] == false
                                  ? null
                                  : () => _startAttendance(slotId),
                              icon: const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Start (5m)',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isOperatingQr || slot['can_end'] == false
                                  ? null
                                  : () => _endAttendance(slotId),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'End (5m)',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(String label, bool isConfirmed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConfirmed
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isConfirmed
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: isConfirmed ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isConfirmed ? AppColors.success : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentHistoryTab() {
    if (_historyData.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            SizedBox(height: 60),
            Center(
              child: Text(
                'No past attendance history records found on the server.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _historyData.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final row = _historyData[idx];
          final status = row['status'] ?? 'unknown';
          final isPresent = status.toString().toLowerCase() == 'present';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isPresent
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  child: Icon(
                    isPresent
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: isPresent ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['course_name'] ??
                            row['course_code'] ??
                            'Class Session',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Date: ${row['date']} • ${row['slot'] ?? row['room_number'] ?? ''}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (row['minutes_present'] != null)
                        Text(
                          'Detected: ${row['minutes_present']} min present',
                          style: TextStyle(
                            color: isPresent
                                ? AppColors.success
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusBadge.status(status),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeacherSessionsTab() {
    final sessionsRaw =
        _overviewData?['sessions'] ?? _overviewData?['week'] ?? [];
    final List<dynamic> sessionList = sessionsRaw is List ? sessionsRaw : [];

    if (sessionList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            SizedBox(height: 60),
            Center(
              child: Text(
                'No active teaching sessions found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: sessionList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final s = sessionList[idx] as Map<String, dynamic>;
          final sessionId = s['id'] ?? s['session_id'] ?? 'SES-$idx';
          final course =
              s['course_name'] ?? s['course_code'] ?? s['subject'] ?? 'Session';
          final section = s['section'] ?? s['section_name'] ?? '';
          final room = s['room_number'] ?? s['room'] ?? '';

          return InkWell(
            onTap: () => _inspectTeacherSession(sessionId.toString()),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Section $section • Room $room',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminCamerasTab() {
    if (_camerasData.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            SizedBox(height: 60),
            Center(
              child: Text(
                'No classroom recognition cameras registered on the server.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _camerasData.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, idx) {
          final cam = _camerasData[idx];
          final name = cam['name'] ?? 'Camera #${cam['id']}';
          final room = cam['room_number'] ?? 'Classroom';
          final status = cam['status'] ?? 'ONLINE';
          final isOnline = status.toString().toUpperCase() == 'ONLINE';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isOnline
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  child: Icon(
                    isOnline ? Icons.videocam : Icons.videocam_off,
                    color: isOnline ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Room: $room • IP: ${cam['ip_address'] ?? 'Auto'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.status(status),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminTimetableTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Timetable OCR Draft Action Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timetable OCR & Publication',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Review OCR draft rows, fix conflicts, and publish.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isOperatingQr ? null : _uploadTimetable,
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Upload Timetable (PDF / image / Excel)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => AdminTimetableDraftSheet.show(
                      context,
                      onPublished: _loadAllData,
                    ),
                    icon: const Icon(Icons.rule_rounded, size: 18),
                    label: const Text('Review & Correct OCR Draft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Published Timetable Slots',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_timetableData.length} active slots',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (_timetableData.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No timetable slots loaded from server.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._timetableData.map((slot) {
              final slotId = slot['id'] ?? slot['slot_id'] ?? 0;
              final course =
                  slot['course_name'] ??
                  slot['course_code'] ??
                  'Class Slot #$slotId';
              final day = slot['day_of_week'] ?? '';
              final time =
                  slot['slot'] ??
                  (slot['start_time'] != null && slot['end_time'] != null
                      ? '${slot['start_time']} - ${slot['end_time']}'
                      : '');
              final room = slot['room_number'] ?? slot['room'] ?? '';
              final section =
                  slot['section_id'] ?? slot['section'] ?? 'Unassigned';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${day.toUpperCase()} • $time',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Room: $room • Section: $section',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Slot #$slotId',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
