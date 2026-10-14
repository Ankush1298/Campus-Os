import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/models/user_session.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/dashboard/screens/dashboard_screen.dart';

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ValueListenableBuilder<UserSession?>(
        valueListenable: AuthService.instance.currentSession,
        builder: (context, session, _) {
          if (session == null) {
            return const LoginScreen();
          }
          return DashboardScreen(session: session);
        },
      ),
    );
  }
}
