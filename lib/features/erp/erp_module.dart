import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shared_widgets.dart';

/// Module Boundary: ERP & Leave Management
/// Owned by: Person 2
/// Git Branch: feature/erp-leave
///
/// Guidelines for Person 2:
/// - Keep your screens and widgets isolated inside `lib/features/erp/`.
/// - Return your entry point widget via [ErpModule.getEntryPoint(context)].
/// - Export your public interface through this file.
class ErpModule {
  static const String moduleName = 'ERP & Leave Portal';
  static const String version = '0.1.0-wip';
  static const String owner = 'Person 2 (feature/erp-leave)';

  static Widget getEntryPoint(BuildContext context) {
    return const ErpPlaceholderScreen();
  }
}

class ErpPlaceholderScreen extends StatelessWidget {
  const ErpPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ERP & Leave Management'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 36,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ERP & Leave Module',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              StatusBadge.status('IN PROGRESS'),
              const SizedBox(height: 16),
              const Text(
                'This module is owned by Person 2 on branch `feature/erp-leave`.\n'
                'Features in progress:\n'
                '• Student & Staff Leave Applications\n'
                '• Leave approval hierarchy\n'
                '• Fee invoices & payment status\n'
                '• Academic calendar & grade sheets',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Branch: feature/erp-leave',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
