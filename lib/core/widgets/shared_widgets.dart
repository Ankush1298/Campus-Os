import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Role / status badge. Kept as the single entry point older screens use; now rendered by [StatusChip].
class StatusBadge extends StatelessWidget {
  final String text;
  final StatusTone tone;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  factory StatusBadge.role(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const StatusBadge(
          text: 'ADMIN',
          tone: StatusTone.error,
          icon: Icons.admin_panel_settings_outlined,
        );
      case 'teacher':
      case 'faculty':
        return const StatusBadge(
          text: 'FACULTY',
          tone: StatusTone.info,
          icon: Icons.school_outlined,
        );
      case 'student':
      default:
        return const StatusBadge(
          text: 'STUDENT',
          tone: StatusTone.brand,
          icon: Icons.badge_outlined,
        );
    }
  }

  factory StatusBadge.status(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'present':
      case 'ready':
      case 'approved':
      case 'synchronized':
        return StatusBadge(
          text: status.toLowerCase() == 'present' ? 'PRESENT' : 'ACTIVE',
          tone: StatusTone.success,
          icon: Icons.check_circle_outline,
        );
      case 'pending':
      case 'in-progress':
      case 'pending end':
        return const StatusBadge(
          text: 'IN PROGRESS',
          tone: StatusTone.warning,
          icon: Icons.timelapse,
        );
      case 'absent':
        return const StatusBadge(
          text: 'ABSENT',
          tone: StatusTone.error,
          icon: Icons.cancel_outlined,
        );
      case 'error':
        return const StatusBadge(
          text: 'ERROR',
          tone: StatusTone.error,
          icon: Icons.error_outline,
        );
      case 'scheduled':
        return const StatusBadge(
          text: 'SCHEDULED',
          tone: StatusTone.neutral,
          icon: Icons.schedule_rounded,
        );
      default:
        return StatusBadge(
          text: status.toUpperCase(),
          tone: StatusTone.neutral,
        );
    }
  }

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: text, tone: tone, icon: icon);
}

/// Navigation tile for a module / destination.
class ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Widget? trailing;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;
  final bool isReady;

  const ModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.iconBgColor = const Color(0xFFE6F4F5),
    this.trailing,
    this.badgeText,
    this.badgeColor,
    this.onTap,
    this.isReady = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(title, style: AppText.heading),
                    if (badgeText != null)
                      StatusChip(
                        label: badgeText!,
                        tone: StatusTone.brand,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppText.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: isReady ? AppColors.textMuted : AppColors.border,
              ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  final String? message;

  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.bodySecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateView({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: AppText.title),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
