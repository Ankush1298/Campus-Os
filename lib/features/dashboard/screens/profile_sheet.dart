import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../auth/models/user_session.dart';
import '../../auth/services/auth_service.dart';

/// Profile, role, session type and sign-out.
Future<void> showProfileSheet(BuildContext context, UserSession s) {
  String host(String url) =>
      Uri.tryParse(url)?.host.isNotEmpty == true ? Uri.parse(url).host : url;
  final attendanceHost = host(ApiClient.baseUrl);
  final erpHost = ApiClient.erpUrl.trim().isEmpty
      ? 'same server as attendance'
      : host(ApiClient.erpBaseUrl);

  Widget row(IconData icon, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        SizedBox(width: 92, child: Text(k, style: AppText.meta)),
        Expanded(
          child: Text(
            v,
            style: AppText.body.copyWith(fontWeight: FontWeight.w600),
            softWrap: true,
          ),
        ),
      ],
    ),
  );

  return showGlassSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.midnight,
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: AppText.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        StatusBadge.role(s.role),
                        if (s.isDemo)
                          const StatusChip(
                            label: 'DEMO',
                            tone: StatusTone.warning,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          row(Icons.badge_outlined, 'ID', s.id),
          row(
            Icons.verified_user_outlined,
            'Session',
            s.isDemo
                ? 'Demo (sample data on this device, no server)'
                : 'Signed in to the campus servers',
          ),
          if (!s.isDemo) row(Icons.dns_outlined, 'Attendance', attendanceHost),
          if (!s.isDemo) row(Icons.apartment_outlined, 'ERP & leave', erpHost),
          row(Icons.info_outline_rounded, 'App', 'CampusOS 1.0'),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: () {
              Navigator.pop(ctx);
              confirmLogout(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

void confirmLogout(BuildContext context) {
  showGlassDialog<void>(
    context,
    builder: (ctx) => GlassDialog(
      title: 'Confirm Logout',
      icon: const Icon(Icons.logout_rounded, color: AppColors.error),
      content: const Text(
        'Are you sure you want to sign out of CampusOS? Your attendance, leave and GeoCam data stay safe.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: const Size(110, AppSpacing.touch),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            AuthService.instance.logout();
          },
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}
