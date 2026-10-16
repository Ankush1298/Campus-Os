import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/branding/brand_splash.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/models/user_session.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/shell/app_shell.dart';

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightOverlay,
        child: child ?? const SizedBox.shrink(),
      ),
      home: ValueListenableBuilder<UserSession?>(
        valueListenable: AuthService.instance.currentSession,
        builder: (context, session, _) {
          return AnimatedSwitcher(
            duration: AppMotion.of(context),
            child: session == null
                ? const LoginScreen(key: ValueKey('login'))
                : AppShell(
                    key: ValueKey('shell-${session.id}-${session.isDemo}'),
                    session: session,
                  ),
          );
        },
      ),
    );
  }
}

/// Restores the saved session behind the branded splash, then shows the app. No artificial delay.
class CampusBootstrap extends StatefulWidget {
  const CampusBootstrap({super.key});

  @override
  State<CampusBootstrap> createState() => _CampusBootstrapState();
}

class _CampusBootstrapState extends State<CampusBootstrap> {
  late final Future<void> _ready = AuthService.instance.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'CampusOS',
            theme: AppTheme.lightTheme,
            home: const BrandSplash(),
          );
        }
        return const CampusApp();
      },
    );
  }
}
