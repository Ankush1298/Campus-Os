import 'package:flutter/material.dart';

import '../../core/widgets/glass.dart';
import '../attendance/screens/attendance_screen.dart';
import '../auth/models/user_session.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../erp/erp_module.dart';
import '../geocam/screens/geocam_screen.dart';
import '../practiverse/practiverse_module.dart';

/// Destinations of the signed-in app. The same five for every role: what is inside each (and what the
/// server allows) is decided by the role, so nothing employee-only is ever offered to a student.
enum ShellTab { home, attendance, campus, capture, learn }

class AppShell extends StatefulWidget {
  final UserSession session;
  final ShellTab initialTab;
  const AppShell({
    super.key,
    required this.session,
    this.initialTab = ShellTab.home,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late ShellTab _tab = widget.initialTab;
  final Set<ShellTab> _visited = {};

  static const _items = <ShellTab, GlassNavItem>{
    ShellTab.home: GlassNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    ShellTab.attendance: GlassNavItem(
      icon: Icons.how_to_reg_outlined,
      selectedIcon: Icons.how_to_reg_rounded,
      label: 'Attendance',
    ),
    ShellTab.campus: GlassNavItem(
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
      label: 'Campus',
    ),
    ShellTab.capture: GlassNavItem(
      icon: Icons.photo_camera_outlined,
      selectedIcon: Icons.photo_camera_rounded,
      label: 'GeoCam',
    ),
    ShellTab.learn: GlassNavItem(
      icon: Icons.science_outlined,
      selectedIcon: Icons.science_rounded,
      label: 'Learn',
    ),
  };

  void _go(ShellTab t) => setState(() => _tab = t);

  Widget _build(ShellTab t, BuildContext context) {
    switch (t) {
      case ShellTab.home:
        return DashboardScreen(session: widget.session, onNavigate: _go);
      case ShellTab.attendance:
        return const AttendanceScreen();
      case ShellTab.campus:
        return ErpModule.getEntryPoint(context);
      case ShellTab.capture:
        return const GeoCamScreen();
      case ShellTab.learn:
        return PractiverseModule.getEntryPoint(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(_tab);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (final t in ShellTab.values)
            // Tabs are built the first time they are opened and then kept alive (so e.g. PractiVerse
            // progress survives a tab switch). The camera tab is torn down when you leave it so the
            // camera and GPS are released.
            if (_visited.contains(t) &&
                (t != ShellTab.capture || _tab == ShellTab.capture))
              Offstage(
                offstage: t != _tab,
                child: TickerMode(
                  enabled: t == _tab,
                  child: _build(t, context),
                ),
              ),
        ],
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : GlassNavigationBar(
              items: [for (final t in ShellTab.values) _items[t]!],
              currentIndex: _tab.index,
              onTap: (i) => _go(ShellTab.values[i]),
            ),
    );
  }
}
