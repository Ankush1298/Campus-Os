import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../models/leave_application.dart';
import '../services/leave_service.dart';
import '../widgets/leave_card.dart';
import '../widgets/leave_detail_sheet.dart';

class StudentLeaveScreen extends StatefulWidget {
  final UserSession session;

  const StudentLeaveScreen({super.key, required this.session});

  @override
  State<StudentLeaveScreen> createState() => _StudentLeaveScreenState();
}

class _StudentLeaveScreenState extends State<StudentLeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  String _selectedLeaveType = 'Hostel Outing';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  final _reasonController = TextEditingController();
  final _destinationController = TextEditingController(text: 'Home, New Delhi');
  final _emergencyController = TextEditingController(text: '+91 98765 43210');

  bool _isSubmitting = false;
  bool _isLoadingList = false;
  String? _formError;
  String? _successBanner;

  List<LeaveApplication> _myLeaves = [];
  String _filterStatus = 'ALL';

  final List<String> _leaveCategories = [
    'Hostel Outing',
    'Home Visit',
    'Medical Leave',
    'Academic / Seminar',
    'Emergency Leave',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    _destinationController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoadingList = true);
    try {
      final leaves = await LeaveService.instance.getStudentLeaves(
        studentId: widget.session.id,
      );
      if (mounted) {
        setState(() {
          _myLeaves = leaves;
          _isLoadingList = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      setState(
        () => _formError = 'End date cannot be earlier than start date.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
      _successBanner = null;
    });

    try {
      final created = await LeaveService.instance.applyStudentLeave(
        authenticatedStudentId: widget.session.id,
        authenticatedStudentName: widget.session.name,
        leaveType: _selectedLeaveType,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text.trim(),
        destinationAddress: _destinationController.text.trim(),
        emergencyContact: _emergencyController.text.trim(),
        department: 'Computer Science & Engineering',
        hostel: 'Hostel Ganga (Block B)',
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _reasonController.clear();
          _successBanner =
              'Leave application ${created.id} submitted successfully! Your assigned warden has been notified.';
        });
        await _loadApplications();
        // Switch to history tab automatically to show the persisted request
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _formError = e is ErpValidationException ? e.message : e.toString();
        });
      }
    }
  }

  Future<void> _handleCancel(LeaveApplication leave) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave Request?'),
        content: Text(
          'Are you sure you want to cancel your leave application #${leave.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await LeaveService.instance.cancelLeave(
        leaveId: leave.id,
        authenticatedStudentId: widget.session.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request successfully cancelled.'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
        _loadApplications();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _formError = null;
      });
    }
  }

  List<LeaveApplication> get _filteredLeaves {
    if (_filterStatus == 'ALL') return _myLeaves;
    return _myLeaves
        .where((l) => l.status.name.toUpperCase() == _filterStatus)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.session.role.toLowerCase() != 'student') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Access denied: student leave applications are for student accounts only.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        // Tab Selector Bar
        Container(
          color: AppColors.glassFillStrong,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: [
              const Tab(
                icon: Icon(Icons.add_circle_outline, size: 18),
                text: 'Apply for Leave',
              ),
              Tab(
                icon: const Icon(Icons.history_rounded, size: 18),
                text: 'My Applications (${_myLeaves.length})',
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildApplyForm(), _buildHistoryList()],
          ),
        ),
      ],
    );
  }

  Widget _buildApplyForm() {
    final days = _endDate.difference(_startDate).inDays + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success / Info Banner
            if (_successBanner != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _successBanner!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _successBanner = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Error Banner
            if (_formError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formError!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Student verified profile chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.glassFillStrong,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Applicant: ${widget.session.name} (${widget.session.id})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Hostel Ganga (Block B) • Warden: Dr. Priya Sen (FAC-CS-08)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Leave Category Dropdown
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedLeaveType,
              decoration: const InputDecoration(
                labelText: 'Leave Category *',
                prefixIcon: Icon(Icons.category_outlined, size: 20),
              ),
              items: _leaveCategories
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedLeaveType = val);
              },
            ),
            const SizedBox(height: 14),

            // Date Range Selector Card
            InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.glassFillStrong,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.date_range_outlined,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Leave Duration (Tap to change dates)',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_startDate.toIso8601String().substring(0, 10)}  to  ${_endDate.toIso8601String().substring(0, 10)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$days ${days == 1 ? "day" : "days"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Destination Address
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination / Staying Address *',
                hintText: 'e.g. Home address or event venue',
                prefixIcon: Icon(Icons.location_on_outlined, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please specify destination address'
                  : null,
            ),
            const SizedBox(height: 14),

            // Emergency Contact
            TextFormField(
              controller: _emergencyController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Phone *',
                hintText: '+91 98765 00000',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter emergency contact number'
                  : null,
            ),
            const SizedBox(height: 14),

            // Reason Text Area
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detailed Reason for Leave *',
                hintText: 'Explain the reason for requesting leave (minimum 10 characters)...',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Reason cannot be empty';
                if (v.trim().length < 10)
                  return 'Reason must be at least 10 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitApplication,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit Official Leave Application'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_isLoadingList) {
      return const LoadingView(message: 'Loading your leave applications...');
    }

    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED']
                .map((st) {
                  final isSel = _filterStatus == st;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st),
                      selected: isSel,
                      onSelected: (_) => setState(() => _filterStatus = st),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ),

        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadApplications,
            color: AppColors.primary,
            child: _filteredLeaves.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 40),
                      const Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _filterStatus == 'ALL'
                              ? 'No leave applications filed yet.'
                              : 'No $_filterStatus applications found.',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Switch to "Apply for Leave" tab to submit a new request.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredLeaves.length,
                    itemBuilder: (ctx, idx) {
                      final leave = _filteredLeaves[idx];
                      return LeaveCard(
                        leave: leave,
                        isWardenView: false,
                        onTap: () => LeaveDetailSheet.show(
                          context,
                          leave: leave,
                          isWarden: false,
                          onCancel: () => _handleCancel(leave),
                        ),
                        onCancel: () => _handleCancel(leave),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
