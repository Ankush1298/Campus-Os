import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/practical_activity.dart';
import '../models/student_progress.dart';
import '../widgets/lives_display_badge.dart';
import '../models/practical_brief.dart';
import '../widgets/practical_brief_card.dart';
import '../widgets/progressive_hint_card.dart';
import '../widgets/recovery_question_dialog.dart';
import '../engine/simulation_renderers/ohms_law_simulation.dart';
import '../engine/simulation_renderers/statistics_simulation.dart';
import '../engine/simulation_renderers/dilution_simulation.dart';
import '../engine/simulation_renderers/code_challenge_simulation.dart';
import '../engine/simulation_renderers/generated_simulation.dart';
import 'flexible_quiz_screen.dart';

class ActivityWorkspaceScreen extends StatefulWidget {
  final PracticalActivity activity;
  final StudentProgress progress;

  const ActivityWorkspaceScreen({
    super.key,
    required this.activity,
    required this.progress,
  });

  @override
  State<ActivityWorkspaceScreen> createState() =>
      _ActivityWorkspaceScreenState();
}

class _ActivityWorkspaceScreenState extends State<ActivityWorkspaceScreen> {
  int _revealedHintsCount = 0;
  bool _completed = false;

  void _onLifeDeducted() {
    setState(() {
      widget.progress.deductLife();
    });
  }

  void _onUnlockHint() {
    if (_revealedHintsCount < widget.activity.hints.length) {
      setState(() {
        _revealedHintsCount++;
        widget.progress.hintsUsed++;
      });
    }
  }

  void _onTriggerRecovery() {
    if (widget.activity.recoveryQuestions.isEmpty) return;
    final recoveryQ = widget.activity.recoveryQuestions.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecoveryQuestionDialog(
        question: recoveryQ,
        onLifeRecovered: () {
          setState(() {
            widget.progress.restoreLife();
            widget.progress.resolveMisconception(recoveryQ.misconceptionTarget);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Concept check passed! +1 Life restored.'),
            ),
          );
        },
        onResetLives: () {
          setState(() {
            widget.progress.resetLives();
          });
        },
      ),
    );
  }

  void _onCompleted() {
    setState(() {
      _completed = true;
      widget.progress.markCompleted(widget.activity.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.title),
        // Generated lessons count their own 3 attempts (shown inside the lesson), not the shared lives.
        actions: widget.activity.kind == ActivityKind.generated
            ? null
            : [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: LivesDisplayBadge(
                key: const Key('practiverse-lives-badge'),
                lives: widget.progress.lives,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Objective & Formula Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E7C86),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.activity.formulaNotation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Difficulty: ${widget.activity.difficulty}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF56667F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.activity.objective,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1B2B4B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Consistent task brief: objective, task, steps, inputs, expected result, validation
            PracticalBriefCard(brief: PracticalBriefs.of(widget.activity)),
            const SizedBox(height: 12),

            // Incremental Hint Card
            ProgressiveHintCard(
              hints: widget.activity.hints,
              revealedCount: _revealedHintsCount,
              onUnlockNextHint: _onUnlockHint,
            ),
            const SizedBox(height: 12),

            // Active Simulation Renderer
            _buildSimulationBody(),

            // Completion Banner & Next Steps
            if (_completed) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Simulation Experiment Mastered!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.activity.kind == ActivityKind.generated
                          ? 'You learned the theory and passed the practical. The quiz is only needed when a practical is missed, so you are done with this lesson.'
                          : widget.activity.kind == ActivityKind.codingChallenge
                          ? 'Your code compiled and passed every visible and hidden test. Verify your conceptual retention with a short diagnostic quiz.'
                          : 'You successfully predicted the mathematical outcome within the tolerance limit. Verify your conceptual retention with a short diagnostic quiz.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2C3C58),
                        height: 1.4,
                      ),
                    ),
                    if (widget.activity.diagnosticQuizQuestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          key: const Key('practiverse-start-quiz'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FlexibleQuizScreen(
                                  questions:
                                      widget.activity.diagnosticQuizQuestions,
                                  subjectId: widget.activity.subjectId,
                                  progress: widget.progress,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.quiz_rounded, size: 18),
                          label: const Text('Start verification quiz'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationBody() {
    switch (widget.activity.kind) {
      case ActivityKind.physicsOhmsLaw:
        return OhmsLawSimulation(
          activity: widget.activity,
          onLifeDeducted: _onLifeDeducted,
          onUnlockHint: _onUnlockHint,
          onTriggerRecovery: _onTriggerRecovery,
          onCompleted: _onCompleted,
          currentLives: widget.progress.lives,
        );
      case ActivityKind.statisticsDataAnalysis:
        return StatisticsSimulation(
          activity: widget.activity,
          onLifeDeducted: _onLifeDeducted,
          onUnlockHint: _onUnlockHint,
          onTriggerRecovery: _onTriggerRecovery,
          onCompleted: _onCompleted,
          currentLives: widget.progress.lives,
        );
      case ActivityKind.chemistryDilution:
        return DilutionSimulation(
          activity: widget.activity,
          onLifeDeducted: _onLifeDeducted,
          onUnlockHint: _onUnlockHint,
          onTriggerRecovery: _onTriggerRecovery,
          onCompleted: _onCompleted,
          currentLives: widget.progress.lives,
        );
      case ActivityKind.codingChallenge:
        return CodeChallengeSimulation(
          activity: widget.activity,
          onLifeDeducted: _onLifeDeducted,
          onUnlockHint: _onUnlockHint,
          onTriggerRecovery: _onTriggerRecovery,
          onCompleted: _onCompleted,
          currentLives: widget.progress.lives,
        );
      case ActivityKind.generated:
        return GeneratedSimulation(
          activity: widget.activity,
          onLifeDeducted: _onLifeDeducted,
          onUnlockHint: _onUnlockHint,
          onTriggerRecovery: _onTriggerRecovery,
          onCompleted: _onCompleted,
          currentLives: widget.progress.lives,
        );
      case ActivityKind.externalVirtualLab:
        return _buildExternalLabCard(widget.activity.externalLab);
    }
  }

  Widget _buildExternalLabCard(ExternalLabResource? lab) {
    if (lab == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.open_in_browser_rounded,
                  color: Color(0xFF0E7C86),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lab.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Provider: ${lab.provider}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              lab.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF46566F)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lab.url,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF2C3C58),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: lab.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Virtual lab URL copied to clipboard!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
