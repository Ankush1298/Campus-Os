import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

export 'models/practical_subject.dart';
export 'models/practical_activity.dart';
export 'models/activity_evaluation.dart';
export 'models/topic_intake_result.dart';
export 'models/student_progress.dart';
export 'engine/activity_registry.dart';
export 'engine/topic_intake_engine.dart';
export 'screens/topic_intake_screen.dart';
export 'screens/activity_workspace_screen.dart';
export 'screens/flexible_quiz_screen.dart';
export 'screens/session_progress_screen.dart';
export 'screens/virtual_labs_directory_screen.dart';

import 'models/student_progress.dart';
import 'engine/activity_registry.dart';
import 'screens/topic_intake_screen.dart';
import 'screens/activity_workspace_screen.dart';
import 'screens/session_progress_screen.dart';
import 'screens/virtual_labs_directory_screen.dart';

/// Public integration boundary for Person 1.
///
/// Dashboard integration already calls:
/// `PractiverseModule.getEntryPoint(context)`.
/// This module owns its internal navigation and session-only progress.
class PractiverseModule {
  static const String moduleName = 'PractiVerse';
  static const String version = '2.0.0';
  static const String owner = 'Person 3 (feature/practiverse)';

  static Widget getEntryPoint(BuildContext context) {
    return const PractiverseHomeScreen(quizTimeLimitSeconds: 120);
  }
}

enum ChallengeDifficulty { beginner, intermediate }

class PractiverseRecoveryQuestion {
  const PractiverseRecoveryQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class PractiverseChallenge {
  const PractiverseChallenge({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.description,
    required this.statement,
    required this.exampleInput,
    required this.exampleOutput,
    required this.expectedAnswer,
    required this.hints,
    required this.testCases,
    required this.icon,
    this.recoveryQuestion,
  });

  final String id;
  final String title;
  final ChallengeDifficulty difficulty;
  final String description;
  final String statement;
  final String exampleInput;
  final String exampleOutput;
  final String expectedAnswer;
  final List<String> hints;
  final List<PractiverseTestCase> testCases;
  final IconData icon;
  final PractiverseRecoveryQuestion? recoveryQuestion;

  String get difficultyLabel =>
      difficulty == ChallengeDifficulty.beginner ? 'Beginner' : 'Intermediate';
}

class PractiverseTestCase {
  const PractiverseTestCase(this.label, this.expected);
  final String label;
  final String expected;
}

const List<PractiverseChallenge> practiverseChallenges = [
  PractiverseChallenge(
    id: 'sum-two',
    title: 'Sum Two Numbers',
    difficulty: ChallengeDifficulty.beginner,
    description: 'Read two integers and return their sum.',
    statement: 'Given two integers, calculate and return their sum. For this demo, enter the numeric result in the answer field.',
    exampleInput: '4 7',
    exampleOutput: '11',
    expectedAnswer: '11',
    hints: [
      'Use addition, not multiplication.',
      'Add the two values in the example input: 4 + 7.',
    ],
    testCases: [
      PractiverseTestCase('Example: 4 + 7', '11'),
      PractiverseTestCase('Zero boundary', '0'),
      PractiverseTestCase('Negative values', '-3'),
    ],
    icon: Icons.calculate_outlined,
    recoveryQuestion: PractiverseRecoveryQuestion(
      prompt: 'Concept check: What is the sum of 0 and any integer n?',
      options: ['n', '0', '1', 'n + 1'],
      correctIndex: 0,
      explanation: '0 is the additive identity: 0 + n = n.',
    ),
  ),
  PractiverseChallenge(
    id: 'even-odd',
    title: 'Even or Odd',
    difficulty: ChallengeDifficulty.beginner,
    description: 'Identify whether an integer is even or odd.',
    statement: 'Return EVEN when a number is divisible by 2; otherwise return ODD. Enter the expected label for the sample input.',
    exampleInput: '14',
    exampleOutput: 'EVEN',
    expectedAnswer: 'EVEN',
    hints: [
      'An even integer has remainder zero when divided by 2.',
      '14 divided by 2 leaves no remainder.',
    ],
    testCases: [
      PractiverseTestCase('Example: 14', 'EVEN'),
      PractiverseTestCase('Odd number: 9', 'ODD'),
      PractiverseTestCase('Zero boundary', 'EVEN'),
    ],
    icon: Icons.alt_route_outlined,
    recoveryQuestion: PractiverseRecoveryQuestion(
      prompt: 'Concept check: Which remainder indicates an even number when divided by 2?',
      options: ['0', '1', '2', '-1'],
      correctIndex: 0,
      explanation: 'An even number leaves remainder 0 upon division by 2.',
    ),
  ),
  PractiverseChallenge(
    id: 'reverse-text',
    title: 'Reverse a String',
    difficulty: ChallengeDifficulty.intermediate,
    description: 'Return a string with its characters in reverse order.',
    statement: 'Reverse the sample word. Enter the expected reversed text in the answer field.',
    exampleInput: 'campus',
    exampleOutput: 'supmac',
    expectedAnswer: 'supmac',
    hints: [
      'The last character becomes the first.',
      'Read campus from right to left.',
    ],
    testCases: [
      PractiverseTestCase('Example: campus', 'supmac'),
      PractiverseTestCase('Single character', 'x'),
      PractiverseTestCase('Palindrome', 'level'),
    ],
    icon: Icons.swap_horiz_rounded,
    recoveryQuestion: PractiverseRecoveryQuestion(
      prompt: "Concept check: What is the first letter of 'dart' reversed?",
      options: ['t', 'd', 'a', 'r'],
      correctIndex: 0,
      explanation: "Reversing 'dart' yields 'trad', which starts with 't'.",
    ),
  ),
];

class PractiverseHomeScreen extends StatefulWidget {
  const PractiverseHomeScreen({this.quizTimeLimitSeconds, super.key});
  final int? quizTimeLimitSeconds;

  @override
  State<PractiverseHomeScreen> createState() => _PractiverseHomeScreenState();
}

class _PractiverseHomeScreenState extends State<PractiverseHomeScreen> {
  final Set<String> _completedChallenges = {};
  final Map<String, int> _livesByChallenge = {};
  String _filter = 'All';
  int _quizScore = 0;
  bool _quizCompleted = false;
  bool _showResults = false;
  late final StudentProgress _sharedProgress;

  @override
  void initState() {
    super.initState();
    _sharedProgress = StudentProgress();
  }

  void _openSimulation(String activityId) {
    final act = ActivityRegistry.getById(activityId);
    if (act == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ActivityWorkspaceScreen(activity: act, progress: _sharedProgress),
      ),
    );
  }

  int get _totalLives => practiverseChallenges.fold<int>(
    0,
    (sum, challenge) => sum + (_livesByChallenge[challenge.id] ?? 3),
  );

  List<PractiverseChallenge> get _visibleChallenges {
    if (_filter == 'Completed') {
      return practiverseChallenges
          .where((challenge) => _completedChallenges.contains(challenge.id))
          .toList();
    }
    if (_filter == 'Not started') {
      return practiverseChallenges
          .where((challenge) => !_completedChallenges.contains(challenge.id))
          .toList();
    }
    return practiverseChallenges;
  }

  void _openChallenge(PractiverseChallenge challenge) {
    final isDone = _completedChallenges.contains(challenge.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PractiverseChallengeScreen(
          challenge: challenge,
          initialLives: _livesByChallenge[challenge.id] ?? 3,
          isCompleted: isDone,
          onLivesChanged: (lives) {
            if (!mounted) return;
            setState(() => _livesByChallenge[challenge.id] = lives);
          },
          onCompleted: () {
            if (!mounted) return;
            setState(() => _completedChallenges.add(challenge.id));
          },
        ),
      ),
    );
  }

  void _openQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PractiverseQuizScreen(
          timeLimitSeconds: widget.quizTimeLimitSeconds,
          onCompleted: (score) {
            if (!mounted) return;
            setState(() {
              _quizScore = score;
              _quizCompleted = true;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completedChallenges.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PractiVerse'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'External Virtual Labs',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const VirtualLabsDirectoryScreen(),
              ),
            ),
            icon: const Icon(Icons.language_rounded),
          ),
          IconButton(
            tooltip: 'Learning Progress & Mastery',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SessionProgressScreen(progress: _sharedProgress),
              ),
            ),
            icon: const Icon(Icons.assessment_outlined),
          ),
          IconButton(
            tooltip: 'Session results',
            onPressed: () => setState(() => _showResults = !_showResults),
            icon: const Icon(Icons.insights_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'LEARN BY DOING',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '3 labs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Build skills.\nSolve real challenges.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$completed of ${practiverseChallenges.length} challenges completed',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: completed / practiverseChallenges.length,
                      minHeight: 7,
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.bolt_rounded,
                    label: 'CHALLENGES',
                    value: '${practiverseChallenges.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.favorite_outline,
                    label: 'LIVES LEFT',
                    value: '$_totalLives',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.quiz_outlined,
                    label: 'QUIZ',
                    value: _quizCompleted ? '$_quizScore/5' : 'Ready',
                  ),
                ),
              ],
            ),
            if (_showResults) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session results',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Challenges completed: $completed / 3'),
                      Text(
                        'Quiz: ${_quizCompleted ? '$_quizScore / 5' : 'Not attempted'}',
                      ),
                      Text('Lives remaining across challenges: $_totalLives'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            // AI Syllabus Intake Banner
            Card(
              key: const Key('practiverse-intake-card'),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TopicIntakeScreen(progress: _sharedProgress),
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
                              'AI Syllabus Intake & Discovery',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enter chapter topics or notes to discover custom multi-subject practicals.',
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
            const SizedBox(height: 20),
            // Multi-Subject Practical Simulations Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SIMULATION ENGINE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Multi-subject practicals',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VirtualLabsDirectoryScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'External Labs',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSimulationCard(
              title: "Physics: Ohm's Law & DC Circuits",
              subtitle: 'Interactive circuit with voltage & resistance sliders (I = V / R)',
              icon: Icons.electric_bolt_rounded,
              color: const Color(0xFF0E7C86),
              onTap: () => _openSimulation('physics_ohms_law'),
            ),
            const SizedBox(height: 10),
            _buildSimulationCard(
              title: 'Mathematics: Data Analysis & Outliers',
              subtitle:
                  'Interactive dataset exploring Mean vs. Median sensitivity',
              icon: Icons.functions_rounded,
              color: const Color(0xFF5A6AE8),
              onTap: () => _openSimulation('math_statistics_data'),
            ),
            const SizedBox(height: 10),
            _buildSimulationCard(
              title: 'Chemistry: Solution Dilution',
              subtitle:
                  'Virtual beaker model with solute conservation (C₁V₁ = C₂V₂)',
              icon: Icons.science_rounded,
              color: const Color(0xFF0D9488),
              onTap: () => _openSimulation('chemistry_dilution'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHALLENGE ARENA',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Practical challenges',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_visibleChallenges.length} challenges',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['All', 'Not started', 'Completed'].map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (_visibleChallenges.isEmpty)
              const _EmptyChallenges()
            else
              ..._visibleChallenges.map((challenge) {
                final done = _completedChallenges.contains(challenge.id);
                final lives = _livesByChallenge[challenge.id] ?? 3;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChallengeCard(
                    challenge: challenge,
                    completed: done,
                    lives: lives,
                    onTap: () => _openChallenge(challenge),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_outlined, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text(
                          'Knowledge check',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Complete a 5-question quiz to verify your learning.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openQuiz,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          _quizCompleted
                              ? 'Retake quiz'
                              : 'Start verification quiz',
                        ),
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

  Widget _buildSimulationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
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
    );
  }
}

class PractiverseChallengeScreen extends StatefulWidget {
  const PractiverseChallengeScreen({
    required this.challenge,
    required this.initialLives,
    required this.onLivesChanged,
    required this.onCompleted,
    this.isCompleted = false,
    super.key,
  });

  final PractiverseChallenge challenge;
  final int initialLives;
  final ValueChanged<int> onLivesChanged;
  final VoidCallback onCompleted;
  final bool isCompleted;

  @override
  State<PractiverseChallengeScreen> createState() =>
      _PractiverseChallengeScreenState();
}

class _PractiverseChallengeScreenState
    extends State<PractiverseChallengeScreen> {
  late int _lives;
  late final TextEditingController _answerController;
  bool _evaluating = false;
  bool _completed = false;
  bool _evaluatedThisAttempt = false;
  String? _feedback;
  bool? _lastPassed;
  int _passedCases = 0;
  int _visibleHints = 0;
  bool _recoveryUsed = false;
  int? _selectedRecoveryOption;

  @override
  void initState() {
    super.initState();
    _lives = widget.initialLives.clamp(0, 3);
    _answerController = TextEditingController();
    _completed = widget.isCompleted || _lives == 0;
    if (widget.isCompleted) {
      _lastPassed = true;
      _passedCases = widget.challenge.testCases.length;
      _answerController.text = widget.challenge.expectedAnswer;
      _feedback = 'Challenge previously completed in this session.';
    } else if (_lives == 0) {
      _feedback = 'No lives left for this challenge. Review the hints or return to the catalogue.';
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_evaluating || _completed || _evaluatedThisAttempt) return;
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _feedback = 'Enter an answer before checking.');
      return;
    }

    setState(() {
      _evaluating = true;
      _feedback = null;
    });

    // Deterministic demo evaluation; this does not execute submitted code.
    final passed =
        answer.toLowerCase() == widget.challenge.expectedAnswer.toLowerCase();
    final passedCases = passed ? widget.challenge.testCases.length : 0;

    setState(() {
      _evaluating = false;
      _evaluatedThisAttempt = true;
      _lastPassed = passed;
      _passedCases = passedCases;
      if (passed) {
        _feedback =
            'All ${widget.challenge.testCases.length} simulated test cases passed.';
        _completed = true;
        widget.onCompleted();
      } else {
        _lives = (_lives - 1).clamp(0, 3);
        widget.onLivesChanged(_lives);
        _feedback = _lives == 0
            ? (widget.challenge.recoveryQuestion != null && !_recoveryUsed
                  ? 'No lives left! Answer the recovery question below to earn +1 life.'
                  : 'No lives left. Review the hints and return to the catalogue.')
            : 'Some tests failed. Review the result, use a hint, then retry.';
        if (_lives == 0) _completed = true;
      }
    });
  }

  void _retry() {
    if (_lives <= 0 || _lastPassed == true) return;
    setState(() {
      _evaluatedThisAttempt = false;
      _feedback = null;
      _lastPassed = null;
      _passedCases = 0;
      _answerController.clear();
    });
  }

  void _submitRecovery() {
    final q = widget.challenge.recoveryQuestion;
    if (q == null || _selectedRecoveryOption == null) return;
    if (_selectedRecoveryOption == q.correctIndex) {
      setState(() {
        _recoveryUsed = true;
        _lives = 1;
        _completed = false;
        _evaluatedThisAttempt = false;
        _lastPassed = null;
        _passedCases = 0;
        _answerController.clear();
        _feedback =
            'Recovery successful! +1 life granted. Review the hints and retry.';
      });
      widget.onLivesChanged(_lives);
    } else {
      setState(() {
        _recoveryUsed = true;
        _feedback =
            'Recovery answer incorrect. Correct answer was: ${q.options[q.correctIndex]}. No further lives recovered.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge workspace'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                avatar: const Icon(
                  Icons.favorite,
                  color: AppColors.error,
                  size: 17,
                ),
                label: Text('$_lives lives'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    challenge.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _DifficultyBadge(label: challenge.difficultyLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              challenge.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Problem statement',
              icon: Icons.description_outlined,
              child: Text(challenge.statement),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Example',
              icon: Icons.terminal_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Input',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _CodeSample(challenge.exampleInput),
                  const SizedBox(height: 8),
                  const Text(
                    'Expected output',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _CodeSample(challenge.exampleOutput),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Your answer',
              icon: Icons.edit_note_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demo mode: enter the expected output, not executable source code.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('practiverse-answer'),
                    controller: _answerController,
                    enabled: !_completed && !_evaluatedThisAttempt,
                    decoration: const InputDecoration(
                      labelText: 'Expected output',
                      hintText: 'Type your answer',
                      prefixIcon: Icon(Icons.code_rounded),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _checkAnswer(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('practiverse-check'),
                      onPressed:
                          _completed || _evaluatedThisAttempt || _evaluating
                          ? null
                          : _checkAnswer,
                      icon: _evaluating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _evaluating ? 'Checking…' : 'Run / Check answer',
                      ),
                    ),
                  ),
                  if (_evaluatedThisAttempt &&
                      _lastPassed == false &&
                      _lives > 0) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry with remaining lives'),
                    ),
                  ],
                ],
              ),
            ),
            if (_feedback != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('practiverse-feedback'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      (_lastPassed == true
                              ? AppColors.success
                              : _lastPassed == false
                              ? AppColors.error
                              : AppColors.info)
                          .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        (_lastPassed == true
                                ? AppColors.success
                                : _lastPassed == false
                                ? AppColors.error
                                : AppColors.info)
                            .withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lastPassed == true
                          ? 'Challenge passed'
                          : _lastPassed == false
                          ? 'Evaluation result'
                          : 'Check your answer',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(_feedback!),
                    if (_lastPassed != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Test cases passed: $_passedCases / ${challenge.testCases.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Evaluation simulation — no arbitrary code was executed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_completed) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('practiverse-return-catalogue'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Return to challenges'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Hints',
              icon: Icons.lightbulb_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reveal a hint whenever you need a nudge. Lives are not consumed.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _visibleHints >= challenge.hints.length
                        ? null
                        : () => setState(() => _visibleHints++),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(
                      _visibleHints == challenge.hints.length
                          ? 'All hints revealed'
                          : 'Reveal hint ($_visibleHints/${challenge.hints.length})',
                    ),
                  ),
                  for (var i = 0; i < _visibleHints; i++) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Hint ${i + 1}: ${challenge.hints[i]}'),
                    ),
                  ],
                ],
              ),
            ),
            if (_lives == 0 &&
                widget.challenge.recoveryQuestion != null &&
                !_recoveryUsed) ...[
              const SizedBox(height: 18),
              _SectionCard(
                title: 'Life Recovery Question',
                icon: Icons.healing_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Out of lives! Answer this concept question correctly to recover +1 life and continue learning.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.challenge.recoveryQuestion!.prompt,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<int>(
                      groupValue: _selectedRecoveryOption,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedRecoveryOption = val);
                        }
                      },
                      child: Column(
                        children: [
                          for (
                            var i = 0;
                            i <
                                widget
                                    .challenge
                                    .recoveryQuestion!
                                    .options
                                    .length;
                            i++
                          )
                            RadioListTile<int>(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: i,
                              title: Text(
                                widget.challenge.recoveryQuestion!.options[i],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('practiverse-recovery-submit'),
                        onPressed: _selectedRecoveryOption == null
                            ? null
                            : _submitRecovery,
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text('Submit recovery answer (+1 life)'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PractiverseQuizScreen extends StatefulWidget {
  const PractiverseQuizScreen({
    required this.onCompleted,
    this.timeLimitSeconds,
    super.key,
  });

  final ValueChanged<int> onCompleted;
  final int? timeLimitSeconds;

  @override
  State<PractiverseQuizScreen> createState() => _PractiverseQuizScreenState();
}

class _PractiverseQuizScreenState extends State<PractiverseQuizScreen> {
  static const List<_QuizQuestion> _questions = [
    _QuizQuestion(
      'Which operator adds two numbers?',
      ['+', '*', '/', '%'],
      0,
      'The + operator performs addition.',
    ),
    _QuizQuestion(
      'When is an integer even?',
      [
        'When it is positive',
        'When remainder after division by 2 is zero',
        'When it ends in 5',
        'When it is greater than 10',
      ],
      1,
      'Even integers are divisible by 2 without a remainder.',
    ),
    _QuizQuestion(
      'What does reversing a string do?',
      [
        'Sorts characters alphabetically',
        'Removes duplicate characters',
        'Places characters in reverse order',
        'Converts it to a number',
      ],
      2,
      'Reversal changes the character order from end to start.',
    ),
    _QuizQuestion(
      'What should happen after an empty answer?',
      [
        'Lose a life',
        'Auto-pass',
        'Reject it without consuming a life',
        'Submit it twice',
      ],
      2,
      'Invalid empty input is rejected before evaluation.',
    ),
    _QuizQuestion(
      'What does this MVP use to check answers?',
      [
        'Unrestricted server execution',
        'Deterministic expected-answer simulation',
        'A remote leaderboard',
        'A compiler service',
      ],
      1,
      'The MVP compares input with predefined expected answers.',
    ),
  ];

  final Map<int, int> _answers = {};
  bool _submitted = false;
  Timer? _timer;
  int? _remainingSeconds;

  @override
  void initState() {
    super.initState();
    if (widget.timeLimitSeconds != null && widget.timeLimitSeconds! > 0) {
      _remainingSeconds = widget.timeLimitSeconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_remainingSeconds != null && _remainingSeconds! > 0) {
          setState(() {
            _remainingSeconds = _remainingSeconds! - 1;
            if (_remainingSeconds == 0) {
              timer.cancel();
              _submit();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _score => _questions
      .asMap()
      .entries
      .where((entry) => _answers[entry.key] == entry.value.correctIndex)
      .length;

  void _submit() {
    if (_submitted) return;
    _timer?.cancel();
    setState(() => _submitted = true);
    widget.onCompleted(_score);
  }

  @override
  Widget build(BuildContext context) {
    final answered = _answers.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Verification quiz')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KNOWLEDGE CHECK',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _submitted ? 'Quiz complete' : 'Question practice',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _submitted
                        ? 'Your score: $_score / ${_questions.length}'
                        : _remainingSeconds != null
                        ? '$answered of ${_questions.length} answered · Timed verification'
                        : '$answered of ${_questions.length} answered · No time limit in this MVP',
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_remainingSeconds != null && !_submitted) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Time left: ${_remainingSeconds! ~/ 60}:${(_remainingSeconds! % 60).toString().padLeft(2, '0')}',
                            key: const Key('practiverse-quiz-timer'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < _questions.length; i++) ...[
              _QuizQuestionCard(
                number: i + 1,
                question: _questions[i],
                selected: _answers[i],
                submitted: _submitted,
                onSelected: (index) => setState(() => _answers[i] = index),
              ),
              const SizedBox(height: 12),
            ],
            if (_submitted)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _score >= 4 ? 'Great work!' : 'Keep practising',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('You scored $_score out of ${_questions.length}.'),
                      const SizedBox(height: 8),
                      const Text(
                        'Your result has been saved for this session.',
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('practiverse-quiz-return'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to PractiVerse'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('practiverse-submit-quiz'),
                  onPressed: _answers.length == _questions.length
                      ? _submit
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Submit quiz'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion(
    this.prompt,
    this.options,
    this.correctIndex,
    this.explanation,
  );
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.submitted,
    required this.onSelected,
  });

  final int number;
  final _QuizQuestion question;
  final int? selected;
  final bool submitted;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUESTION $number OF 5',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) {
                if (!submitted && value != null) {
                  onSelected(value);
                }
              },
              child: Column(
                children: [
                  for (var i = 0; i < question.options.length; i++)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: i,
                      enabled: !submitted,
                      title: Text(question.options[i]),
                    ),
                ],
              ),
            ),
            if (submitted) ...[
              const Divider(),
              Text(
                selected == question.correctIndex
                    ? 'Correct — ${question.explanation}'
                    : 'Correct answer: ${question.options[question.correctIndex]}. ${question.explanation}',
                style: TextStyle(
                  color: selected == question.correctIndex
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.completed,
    required this.lives,
    required this.onTap,
  });

  final PractiverseChallenge challenge;
  final bool completed;
  final int lives;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppColors.success : AppColors.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  completed ? Icons.check_circle_outline : challenge.icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _DifficultyBadge(label: challenge.difficultyLabel),
                        _MiniBadge(
                          label: completed ? 'COMPLETED' : '$lives LIVES',
                          color: color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(height: 7),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CodeSample extends StatelessWidget {
  const _CodeSample(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1B3A),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFFB3DFE4),
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final beginner = label == 'Beginner';
    return _MiniBadge(
      label: label.toUpperCase(),
      color: beginner ? AppColors.accent : const Color(0xFF5A6AE8),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EmptyChallenges extends StatelessWidget {
  const _EmptyChallenges();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            'Nothing here yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Try another filter to see available challenges.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
