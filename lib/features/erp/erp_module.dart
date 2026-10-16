import 'package:flutter/material.dart';

import 'screens/erp_portal_screen.dart';

export 'models/leave_application.dart';
export 'models/warden_assignment.dart';
export 'models/employee_profile.dart';
export 'models/student_academic_profile.dart';
export 'services/leave_service.dart';
export 'screens/erp_portal_screen.dart';
export 'screens/student_leave_screen.dart';
export 'screens/warden_inbox_screen.dart';
export 'screens/employee_leave_screen.dart';
export 'screens/academic_profile_screen.dart';
export 'widgets/leave_card.dart';
export 'widgets/leave_detail_sheet.dart';

/// Module Boundary: ERP & Leave Management
/// Owned by: Person 2
/// Git Branch: feature/erp-leave
///
/// Guidelines for Person 2:
/// - Keep all screens, widgets, and services isolated inside `lib/features/erp/`.
/// - Return your entry point widget via [ErpModule.getEntryPoint(context)].
/// - Export your public interface through this file.
class ErpModule {
  static const String moduleName = 'ERP & Leave Portal';
  static const String version = '1.0.0-ready';
  static const String owner = 'Person 2 (feature/erp-leave)';

  /// Primary Entry Point invoked by Person 1's DashboardScreen
  static Widget getEntryPoint(BuildContext context) {
    return const ErpPortalScreen();
  }
}
