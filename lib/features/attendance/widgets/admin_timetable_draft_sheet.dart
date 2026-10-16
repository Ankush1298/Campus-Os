import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../services/attendance_service.dart';

class AdminTimetableDraftSheet extends StatefulWidget {
  final String? initialDraftId;
  final VoidCallback? onPublished;

  const AdminTimetableDraftSheet({
    super.key,
    this.initialDraftId,
    this.onPublished,
  });

  static Future<void> show(
    BuildContext context, {
    String? draftId,
    VoidCallback? onPublished,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminTimetableDraftSheet(
        initialDraftId: draftId,
        onPublished: onPublished,
      ),
    );
  }

  @override
  State<AdminTimetableDraftSheet> createState() =>
      _AdminTimetableDraftSheetState();
}

class _AdminTimetableDraftSheetState extends State<AdminTimetableDraftSheet> {
  bool _isLoading = false;
  String? _draftId;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _issues = [];
  int _errorsCount = 0;
  int _warningsCount = 0;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _draftId = widget.initialDraftId;
    if (_draftId != null) {
      _loadDraft(_draftId!);
    } else {
      _loadSampleDraft();
    }
  }

  void _loadSampleDraft() {
    setState(() {
      _rows = [
        {
          'day': 'Monday',
          'start': '09:00',
          'end': '09:50',
          'subject': 'Data Structures',
          'teacher': 'T_SHARMA',
          'room': 'CR-101',
          'section': 'CS-A',
        },
        {
          'day': 'Monday',
          'start': '10:00',
          'end': '10:50',
          'subject': 'Computer Networks',
          'teacher': 'T_VERMA',
          'room': 'CR-102',
          'section': 'CS-A',
        },
      ];
      _draftId = 'draft_preview_temp';
      _errorsCount = 0;
      _warningsCount = 0;
    });
  }

  bool get _isDemoMode =>
      (AuthService.instance.currentSession.value?.isDemo ?? true) ||
      (_draftId?.contains('demo') ?? false);

  Future<void> _loadDraft(String draftId) async {
    setState(() => _isLoading = true);
    try {
      final res = await AttendanceService.instance.getTimetableDraft(
        draftId,
        isDemo: _isDemoMode || draftId.contains('demo'),
      );
      final rowsRaw = res['rows'] as List<dynamic>? ?? [];
      final issuesRaw = res['issues'] as List<dynamic>? ?? [];

      setState(() {
        _draftId = draftId;
        _rows = rowsRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _issues = issuesRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _errorsCount = res['errors'] ?? 0;
        _warningsCount = res['warnings'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to load draft: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _saveAndValidate() async {
    if (_draftId == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await AttendanceService.instance.updateTimetableDraft(
        draftId: _draftId!,
        rows: _rows,
        isDemo: _isDemoMode,
      );

      final rowsRaw = res['rows'] as List<dynamic>? ?? [];
      final issuesRaw = res['issues'] as List<dynamic>? ?? [];

      setState(() {
        _rows = rowsRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _issues = issuesRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _errorsCount = res['errors'] ?? 0;
        _warningsCount = res['warnings'] ?? 0;
        _statusMessage = 'Draft updated and re-validated successfully.';
        _isSuccess = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Validation failed: $e';
        _isSuccess = false;
      });
    }
  }

  Future<void> _publishDraft() async {
    if (_draftId == null || _errorsCount > 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Timetable Publication'),
        content: const Text(
          'Publishing replaces the active institutional timetable. All section sessions and class rosters will update accordingly. Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await AttendanceService.instance.publishTimetableDraft(
        draftId: _draftId!,
        confirm: true,
        isDemo: _isDemoMode,
      );

      final publishedCount =
          res['published_slots'] ?? res['published'] ?? _rows.length;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Timetable published! $publishedCount slots active.';
        _isSuccess = true;
      });

      widget.onPublished?.call();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Publishing error: $e';
        _isSuccess = false;
      });
    }
  }

  void _editRow(int index) async {
    final row = Map<String, dynamic>.from(_rows[index]);
    final dayCtrl = TextEditingController(text: row['day']?.toString());
    final startCtrl = TextEditingController(text: row['start']?.toString());
    final endCtrl = TextEditingController(text: row['end']?.toString());
    final subjCtrl = TextEditingController(text: row['subject']?.toString());
    final teacherCtrl = TextEditingController(text: row['teacher']?.toString());
    final roomCtrl = TextEditingController(text: row['room']?.toString());

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Slot #${index + 1}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject / Course',
                ),
              ),
              TextField(
                controller: dayCtrl,
                decoration: const InputDecoration(
                  labelText: 'Day (e.g. Monday)',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Start Time (09:00)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: const InputDecoration(
                        labelText: 'End Time (09:50)',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: teacherCtrl,
                decoration: const InputDecoration(labelText: 'Teacher ID'),
              ),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Room ID'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (updated == true) {
      setState(() {
        _rows[index] = {
          'day': dayCtrl.text.trim(),
          'start': startCtrl.text.trim(),
          'end': endCtrl.text.trim(),
          'subject': subjCtrl.text.trim(),
          'teacher': teacherCtrl.text.trim(),
          'room': roomCtrl.text.trim(),
        };
      });
      _saveAndValidate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timetable OCR Review & Editing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Draft: ${_draftId ?? "None"} • ${_rows.length} rows',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Issues banner
          if (_issues.isNotEmpty || _statusMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _errorsCount > 0
                    ? const Color(0xFFFEF2F2)
                    : (_warningsCount > 0
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFF0FDF4)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errorsCount > 0
                      ? const Color(0xFFFECACA)
                      : (_warningsCount > 0
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFBBF7D0)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _errorsCount > 0
                            ? Icons.error_outline
                            : Icons.info_outline,
                        size: 18,
                        color: _errorsCount > 0
                            ? AppColors.error
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _errorsCount > 0
                            ? '$_errorsCount error(s) must be corrected before publishing'
                            : (_warningsCount > 0
                                  ? '$_warningsCount warning(s) detected'
                                  : 'Validation Clean'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _errorsCount > 0
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isSuccess ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Rows List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final r = _rows[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.glassFillStrong,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['subject'] ?? 'Untitled',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${r['day']} • ${r['start']} - ${r['end']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    'Teacher: ${r['teacher']} • Room: ${r['room']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _editRow(i),
                              tooltip: 'Edit Slot',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveAndValidate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Re-Validate Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_errorsCount == 0 && _rows.isNotEmpty)
                        ? _publishDraft
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _errorsCount > 0
                          ? 'Fix Errors to Publish'
                          : 'Confirm & Publish',
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
}
