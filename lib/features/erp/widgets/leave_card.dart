import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/leave_application.dart';

class LeaveCard extends StatelessWidget {
  final LeaveApplication leave;
  final bool isWardenView;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onDecide; // true for approve, false for reject

  const LeaveCard({
    super.key,
    required this.leave,
    this.isWardenView = false,
    this.onTap,
    this.onCancel,
    this.onDecide,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: leave.isPending ? const Color(0xFFFDE68A) : AppColors.border,
          width: leave.isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Type & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: leave.status.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getIconForType(leave.leaveType),
                              size: 18,
                              color: leave.status.color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leave.leaveType,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'ID: ${leave.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusPill(leave.status),
                  ],
                ),
                const SizedBox(height: 12),

                // If Warden view, display student identity
                if (isWardenView) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${leave.applicantName} (${leave.applicantId})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (leave.hostel != null)
                          Text(
                            leave.hostel!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Dates & Duration
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    Text(
                      '${_formatDate(leave.startDate)} → ${_formatDate(leave.endDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${leave.durationDays} ${leave.durationDays == 1 ? "day" : "days"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Reason snippet
                Text(
                  leave.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),

                // Decision remarks if available
                if (leave.decisionRemarks != null &&
                    leave.decisionRemarks!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: leave.isApproved
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: leave.isApproved
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              leave.isApproved
                                  ? Icons.verified_user_outlined
                                  : Icons.info_outline,
                              size: 14,
                              color: leave.isApproved
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Decision by ${leave.decidedBy ?? "Approver"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: leave.isApproved
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          leave.decisionRemarks!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Bar
                if (isWardenView && leave.isPending && onDecide != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onDecide!(false),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onDecide!(true),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (!isWardenView &&
                    leave.isPending &&
                    onCancel != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 15,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Cancel Request',
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(LeaveStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: status.color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('outing')) return Icons.directions_walk_rounded;
    if (lower.contains('home')) return Icons.home_outlined;
    if (lower.contains('medical')) return Icons.medical_services_outlined;
    if (lower.contains('casual')) return Icons.beach_access_outlined;
    if (lower.contains('duty')) return Icons.work_outline;
    if (lower.contains('sick')) return Icons.healing_outlined;
    return Icons.assignment_outlined;
  }
}
