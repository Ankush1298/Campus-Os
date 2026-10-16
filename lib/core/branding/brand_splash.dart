import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'campus_logo.dart';

/// In-app splash shown while the saved session is restored. Matches the native Android splash
/// (navy + symbol) so the hand-off is seamless; it never adds an artificial delay.
class BrandSplash extends StatelessWidget {
  final String? message;
  const BrandSplash({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CampusLogo(
                markSize: 84,
                tone: CampusLogoTone.onDark,
                stacked: true,
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: BrandColors.teal,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 14),
                Text(
                  message!,
                  style: const TextStyle(
                    color: Color(0xFFB9C6DD),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
