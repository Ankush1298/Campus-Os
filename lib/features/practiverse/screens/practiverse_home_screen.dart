import 'package:flutter/material.dart';

import '../models/student_progress.dart';
import '../models/practical_activity.dart';
import '../engine/activity_registry.dart';
import '../widgets/lives_display_badge.dart';
import 'topic_intake_screen.dart';
import 'activity_workspace_screen.dart';
import 'flexible_quiz_screen.dart';
import 'session_progress_screen.dart';
import 'virtual_labs_directory_screen.dart';

class PractiverseHomeScreen extends StatefulWidget {
  final StudentProgress? progress;

  const PractiverseHomeScreen({super.key, this.progress});

  @override
  State<PractiverseHomeScreen> createState() => _PractiverseHomeScreenState();
}

class _PractiverseHomeScreenState extends State<PractiverseHomeScreen> {
  late final StudentProgress _progress;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _progress = widget.progress ?? StudentProgress();
  }

  List<PracticalActivity> get _filteredActivities {
    if (_selectedCategory == 'all') {
      return ActivityRegistry.allActivities;
    }
    return ActivityRegistry.getBySubject(_selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final activities = _filteredActivities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PractiVerse'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(child: LivesDisplayBadge(lives: _progress.lives)),
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Session Progress',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SessionProgressScreen(progress: _progress),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1B3A), Color(0xFF0E7C86)],
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.science_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '3 labs',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const VirtualLabsDirectoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.language_rounded, size: 16),
                        label: const Text(
                          'External Labs',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Build skills.\nSolve real challenges.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Multi-subject practical simulation platform covering Physics, Mathematics, Chemistry, and Computer Science.',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AI Syllabus Intake Action Card
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TopicIntakeScreen(progress: _progress),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Color(0xFF0E7C86),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explore Syllabus / AI Intake',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enter chapter topics or notes to discover custom practicals.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF56667F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Disciplines', 'all'),
                  _buildFilterChip('Physics', 'physics'),
                  _buildFilterChip('Math & Stats', 'mathematics'),
                  _buildFilterChip('Chemistry', 'chemistry'),
                  _buildFilterChip('Computer Science', 'computer_science'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List of Practical Activities & Simulations
            for (final act in activities) ...[
              _buildActivityCard(context, act),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 12),

            // Verification Quiz Section
            Card(
              color: const Color(0xFFF8FAFC),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.quiz_rounded,
                          color: Color(0xFF0E7C86),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Timed Verification Quiz',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Verify your practical retention across active subject modules.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF56667F)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('practiverse-start-quiz-btn'),
                        onPressed: () {
                          // Select diagnostic questions from active subject
                          final targetAct = activities.first;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FlexibleQuizScreen(
                                questions: targetAct.diagnosticQuizQuestions,
                                subjectId: targetAct.subjectId,
                                progress: _progress,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E7C86),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start verification quiz'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String categoryId) {
    final selected = _selectedCategory == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedCategory = categoryId;
          });
        },
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, PracticalActivity act) {
    final isDone = _progress.completedActivityIds.contains(act.id);
    Color chipColor = const Color(0xFF0E7C86);
    if (act.subjectId == 'mathematics') chipColor = const Color(0xFF5A6AE8);
    if (act.subjectId == 'chemistry') chipColor = const Color(0xFF0D9488);
    if (act.subjectId == 'computer_science') {
      chipColor = const Color(0xFF0284C7);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ActivityWorkspaceScreen(activity: act, progress: _progress),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      act.formulaNotation,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: chipColor,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (isDone)
                        const Padding(
                          padding: EdgeInsets.only(right: 6.0),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 16,
                          ),
                        ),
                      Text(
                        act.difficulty,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF56667F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                act.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                act.conceptTested,
                style: const TextStyle(fontSize: 13, color: Color(0xFF46566F)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    act.isVirtualSimulation
                        ? 'Interactive Simulation'
                        : 'External Virtual Lab',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF56667F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF0E7C86),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
