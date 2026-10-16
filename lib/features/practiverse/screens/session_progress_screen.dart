import 'package:flutter/material.dart';

import '../models/student_progress.dart';
import '../engine/activity_registry.dart';
import '../widgets/lives_display_badge.dart';

class SessionProgressScreen extends StatelessWidget {
  final StudentProgress progress;

  const SessionProgressScreen({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Progress & Mastery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1B3A), Color(0xFF1B2B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Session Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      LivesDisplayBadge(lives: progress.lives),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildOverviewStat(
                        'Completed Labs',
                        '${progress.completedActivityIds.length}',
                        Icons.science_rounded,
                        const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 16),
                      _buildOverviewStat(
                        'Hints Requested',
                        '${progress.hintsUsed}',
                        Icons.lightbulb_rounded,
                        const Color(0xFFFDE047),
                      ),
                      const SizedBox(width: 16),
                      _buildOverviewStat(
                        'Misconceptions Fixed',
                        '${progress.resolvedMisconceptions.length}',
                        Icons.verified_user_rounded,
                        const Color(0xFF4ADE80),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Completed Activities List
            const Text(
              'Completed Simulation Practicals',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (progress.completedActivityIds.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'No practicals completed yet this session. Explore a simulation to begin!',
                    style: TextStyle(color: Color(0xFF56667F), fontSize: 13),
                  ),
                ),
              )
            else
              for (final actId in progress.completedActivityIds) ...[
                _buildActivityTile(actId),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 20),

            // Misconceptions Remediated
            const Text(
              'Resolved Misconceptions',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (progress.resolvedMisconceptions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'No conceptual errors recorded. Excellent baseline understanding!',
                    style: TextStyle(color: Color(0xFF56667F), fontSize: 13),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: progress.resolvedMisconceptions.map((m) {
                  return Chip(
                    avatar: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                    label: Text(
                      m.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: const Color(0xFFDCFCE7),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // Verification Quiz Scores
            const Text(
              'Diagnostic Quiz Scores',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (progress.quizScores.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: Text(
                    'No verification quizzes attempted yet.',
                    style: TextStyle(color: Color(0xFF56667F), fontSize: 13),
                  ),
                ),
              )
            else
              for (final entry in progress.quizScores.entries)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.quiz_rounded,
                      color: Color(0xFF0E7C86),
                    ),
                    title: Text('Subject: ${entry.key.toUpperCase()}'),
                    trailing: Text(
                      '${entry.value}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: entry.value >= 70
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(String activityId) {
    final act = ActivityRegistry.getById(activityId);
    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF16A34A),
        ),
        title: Text(
          act?.title ?? activityId,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(act?.conceptTested ?? 'Practical simulation'),
      ),
    );
  }
}
