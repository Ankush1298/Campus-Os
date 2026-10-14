import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shared_widgets.dart';

/// Module Boundary: PractiVerse (Labs, Practical Work & Projects)
/// Owned by: Person 3
/// Git Branch: feature/practiverse
///
/// Guidelines for Person 3:
/// - Keep your screens and widgets isolated inside `lib/features/practiverse/`.
/// - Return your entry point widget via [PractiverseModule.getEntryPoint(context)].
/// - Export your public interface through this file.
class PractiverseModule {
  static const String moduleName = 'PractiVerse';
  static const String version = '0.1.0-wip';
  static const String owner = 'Person 3 (feature/practiverse)';

  static Widget getEntryPoint(BuildContext context) {
    return const PractiversePlaceholderScreen();
  }
}

class PractiversePlaceholderScreen extends StatelessWidget {
  const PractiversePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PractiVerse'),
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
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.science_outlined,
                  size: 36,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'PractiVerse Lab Module',
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
                'This module is owned by Person 3 on branch `feature/practiverse`.\n'
                'Features in progress:\n'
                '• Virtual Lab assignments & submissions\n'
                '• Code execution & test run logs\n'
                '• Lab equipment booking\n'
                '• Real-time instructor feedback',
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
                  'Branch: feature/practiverse',
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
