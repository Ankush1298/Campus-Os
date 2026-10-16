import 'package:flutter/material.dart';

class LivesDisplayBadge extends StatelessWidget {
  final int lives;
  final int maxLives;

  const LivesDisplayBadge({super.key, required this.lives, this.maxLives = 3});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: lives > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lives > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < maxLives; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(
                i < lives
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 18,
                color: i < lives
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF94A3B8),
              ),
            ),
          const SizedBox(width: 4),
          Text(
            lives > 0 ? '$lives/$maxLives' : '0 lives',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: lives > 0
                  ? const Color(0xFF991B1B)
                  : const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }
}
