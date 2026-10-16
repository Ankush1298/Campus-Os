import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../models/leave_application.dart';
import '../services/leave_service.dart';
import '../widgets/leave_card.dart';
import '../widgets/leave_detail_sheet.dart';

class WardenInboxScreen extends StatefulWidget {
  final UserSession session;

  const WardenInboxScreen({super.key, required this.session});

  @override
  State<WardenInboxScreen> createState() => _WardenInboxScreenState();
}

class _WardenInboxScreenState extends State<WardenInboxScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<LeaveApplication> _applications = [];
  bool _pendingOnly = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await LeaveService.instance.getWardenInbox(
        wardenId: widget.session.id,
        role: widget.session.role,
        pendingOnly: _pendingOnly,
      );
      if (mounted) {
        setState(() {
          _applications = list;
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

  Future<void> _promptDecision(LeaveApplication leave, bool approve) async {
    final remarksController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              approve
                  ? Icons.check_circle_outline
                  : Icons.highlight_off_rounded,
              color: approve ? AppColors.success : AppColors.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(approve ? 'Approve Leave' : 'Reject Leave'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${approve ? "Approve" : "Reject"} application #${leave.id} for student ${leave.applicantName} (${leave.applicantId})?',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: remarksController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: approve
                    ? 'Approval Remarks (Optional)'
                    : 'Reason for Rejection *',
                hintText: approve
                    ? 'e.g. Parental consent verified.'
                    : 'e.g. Exam scheduled during dates.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!approve && remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please provide remarks when rejecting a student leave.',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.success : AppColors.error,
            ),
            child: Text(approve ? 'Confirm Approval' : 'Confirm Rejection'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final updated = await LeaveService.instance.decideLeave(
        leaveId: leave.id,
        approverId: widget.session.id,
        approverName: widget.session.name,
        approverRole: widget.session.role,
        approve: approve,
        remarks: remarksController.text.trim().isNotEmpty
            ? remarksController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Application ${updated.id} successfully ${updated.status.displayName} by ${widget.session.name}.',
            ),
            backgroundColor: approve
                ? AppColors.success
                : AppColors.textPrimary,
          ),
        );
        _loadQueue();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Decision Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        _loadQueue();
      }
    }
  }

  List<LeaveApplication> get _filteredApplications {
    if (_searchQuery.isEmpty) return _applications;
    final q = _searchQuery.toLowerCase();
    return _applications.where((app) {
      return app.applicantName.toLowerCase().contains(q) ||
          app.applicantId.toLowerCase().contains(q) ||
          app.id.toLowerCase().contains(q) ||
          app.leaveType.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // If not authorized as warden, faculty, or admin, show security barrier
    final isAuthorized =
        widget.session.role.toLowerCase() == 'admin' ||
        widget.session.role.toLowerCase() == 'teacher' ||
        widget.session.role.toLowerCase() == 'faculty' ||
        widget.session.role.toLowerCase() == 'warden';

    if (!isAuthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Warden & Approver Access Restricted',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your current session account (${widget.session.name} • ${widget.session.role.toUpperCase()}) does not hold official warden or administrative leave approval privileges.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tip: Switch to Faculty/Warden persona (e.g. Dr. Priya Sen, FAC-CS-08) using the persona selector above to review assigned hostel leaves.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Warden Header Banner (scrolls internally on very small / large-text screens instead of overflowing)
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.glassEdge),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE4E8FF),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.session.name} (${widget.session.id})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              widget.session.role.toLowerCase() == 'admin'
                                  ? 'Administrator: all campus requests'
                                  : 'Requests from the students assigned to you',
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        FilterChip(
                          label: Text(
                            _pendingOnly ? 'Pending Only' : 'All Decisions',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _pendingOnly
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: _pendingOnly,
                          onSelected: (val) {
                            setState(() => _pendingOnly = val);
                            _loadQueue();
                          },
                          selectedColor: const Color(0xFFFEF3C7),
                          checkmarkColor: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Refresh Queue',
                          onPressed: _loadQueue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Search Box
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search by student name, roll number, or leave ID...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Applications List
        Expanded(
          flex: 3,
          child: _isLoading
              ? const LoadingView(message: 'Loading assigned students inbox...')
              : _errorMessage != null
              ? ErrorStateView(message: _errorMessage!, onRetry: _loadQueue)
              : RefreshIndicator(
                  onRefresh: _loadQueue,
                  color: AppColors.primary,
                  child: _filteredApplications.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          children: [
                            const SizedBox(height: 40),
                            const Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                _pendingOnly
                                    ? 'No pending applications in your assigned inbox.'
                                    : 'No applications found.',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Center(
                              child: Text(
                                'All student requests assigned to your hostel/dept are up to date.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _filteredApplications.length,
                          itemBuilder: (ctx, idx) {
                            final leave = _filteredApplications[idx];
                            return LeaveCard(
                              leave: leave,
                              isWardenView: true,
                              onTap: () => LeaveDetailSheet.show(
                                context,
                                leave: leave,
                                isWarden: true,
                                onDecide: (approve) =>
                                    _promptDecision(leave, approve),
                              ),
                              onDecide: (approve) =>
                                  _promptDecision(leave, approve),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
