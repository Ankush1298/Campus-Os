import 'package:flutter/material.dart';

class ProgressiveHintCard extends StatelessWidget {
  final List<String> hints;
  final int revealedCount;
  final VoidCallback onUnlockNextHint;

  const ProgressiveHintCard({
    super.key,
    required this.hints,
    required this.revealedCount,
    required this.onUnlockNextHint,
  });

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) return const SizedBox.shrink();

    final hasMoreHints = revealedCount < hints.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCE8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEF08A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFCA8A04),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Conceptual Hints ($revealedCount/${hints.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF854D0E),
                ),
              ),
              const Spacer(),
              if (hasMoreHints)
                TextButton(
                  key: const Key('practiverse-hint-btn'),
                  onPressed: onUnlockNextHint,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Unlock Hint'),
                ),
            ],
          ),
          if (revealedCount == 0)
            const Padding(
              padding: EdgeInsets.only(top: 6.0),
              child: Text(
                'Need guidance? Unlock incremental hints to break down the concept.',
                style: TextStyle(fontSize: 12, color: Color(0xFF713F12)),
              ),
            )
          else
            ...List.generate(revealedCount, (index) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE047),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF713F12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hints[index],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF713F12),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
