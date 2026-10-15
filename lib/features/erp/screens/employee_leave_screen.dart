import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../models/employee_profile.dart';
import '../models/leave_application.dart';
import '../services/leave_service.dart';
import '../widgets/leave_card.dart';
import '../widgets/leave_detail_sheet.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  final UserSession session;

  const EmployeeLeaveScreen({super.key, required this.session});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  String _leaveType = 'Casual Leave';
  DateTime _startDate = DateTime.now().add(const Duration(days: 2));
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  final _reasonController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = false;
  String? _successMsg;
  String? _errorMsg;

  List<LeaveApplication> _myLeaves = [];
  List<EmployeeProfile> _directory = [];

  final List<String> _types = ['Casual Leave', 'Sick Leave', 'Earned Leave', 'Duty Leave'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final leaves = await LeaveService.instance.getEmployeeLeaves(
        employeeId: widget.session.id,
      );
      final directory = await LeaveService.instance.getEmployeeDirectory();
      if (mounted) {
        setState(() {
          _myLeaves = leaves;
          _directory = directory;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitEmployeeLeave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      setState(() => _errorMsg = 'End date cannot precede start date.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
      _successMsg = null;
    });

    try {
      final app = await LeaveService.instance.applyEmployeeLeave(
        employeeId: widget.session.id,
        employeeName: widget.session.name,
        department: 'Computer Science & Engineering',
        leaveType: _leaveType,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _reasonController.clear();
          _successMsg = 'Employee leave application ${app.id} submitted for institutional review.';
        });
        await _loadData();
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Employee Profile & Leave Quota Card
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Staff ID: ${widget.session.id} • Dept of Computer Science',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.role(widget.session.role),
                ],
              ),
              const SizedBox(height: 14),

              // Quota Badges
              Row(
                children: [
                  _buildQuotaTile('Casual', '10', const Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  _buildQuotaTile('Sick', '8', const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _buildQuotaTile('Earned', '14', const Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  _buildQuotaTile('Duty', '5', const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(text: 'Apply Leave'),
              Tab(text: 'My Leave History'),
              Tab(text: 'Staff Directory'),
            ],
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildApplyTab(),
              _buildHistoryTab(),
              _buildDirectoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuotaTile(String label, String balance, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              balance,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_successMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_successMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFF065F46))),
              ),
              const SizedBox(height: 12),
            ],
            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
              ),
              const SizedBox(height: 12),
            ],

            DropdownButtonFormField<String>(
              initialValue: _leaveType,
              decoration: const InputDecoration(
                labelText: 'Leave Category *',
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _leaveType = val);
              },
            ),
            const SizedBox(height: 14),

            // Start & End Dates
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                      );
                      if (d != null) setState(() => _startDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Start Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(_startDate.toIso8601String().substring(0, 10), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                      );
                      if (d != null) setState(() => _endDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('End Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(_endDate.toIso8601String().substring(0, 10), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Official Reason & Alternate Arrangements *',
                hintText: 'Enter reason and name of colleague handling lecture/lab duties...',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 5) ? 'Please enter a valid reason' : null,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitEmployeeLeave,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit for Department Approval'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) return const LoadingView(message: 'Loading records...');

    if (_myLeaves.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_outlined, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'No employee leave records yet.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myLeaves.length,
      itemBuilder: (ctx, idx) {
        final leave = _myLeaves[idx];
        return LeaveCard(
          leave: leave,
          isWardenView: false,
          onTap: () => LeaveDetailSheet.show(context, leave: leave),
        );
      },
    );
  }

  Widget _buildDirectoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _directory.length,
      itemBuilder: (ctx, idx) {
        final emp = _directory[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  emp.name.isNotEmpty ? emp.name[0] : 'E',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${emp.designation} • ${emp.department}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${emp.email} • ${emp.phone}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.primaryLight),
                    ),
                  ],
                ),
              ),
              StatusBadge.status(emp.status),
            ],
          ),
        );
      },
    );
  }
}
