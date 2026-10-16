import 'dart:async';

import 'package:flutter/material.dart';

import '../models/practical_activity.dart';
import '../models/student_progress.dart';

class FlexibleQuizScreen extends StatefulWidget {
  final List<DiagnosticQuizQuestion> questions;
  final String subjectId;
  final StudentProgress progress;
  final int? timeLimitSeconds;

  const FlexibleQuizScreen({
    super.key,
    required this.questions,
    required this.subjectId,
    required this.progress,
    this.timeLimitSeconds,
  });

  @override
  State<FlexibleQuizScreen> createState() => _FlexibleQuizScreenState();
}

class _FlexibleQuizScreenState extends State<FlexibleQuizScreen> {
  final Map<int, int> _selectedAnswers = {};
  bool _submitted = false;
  int _scorePercent = 0;
  Timer? _timer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    if (widget.timeLimitSeconds != null && widget.timeLimitSeconds! > 0) {
      _secondsRemaining = widget.timeLimitSeconds!;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_secondsRemaining <= 1) {
          timer.cancel();
          _submitQuiz();
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      });
    }
  }

  void _submitQuiz() {
    if (_submitted) return;
    _timer?.cancel();

    int correct = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selectedAnswers[i] == widget.questions[i].correctIndex) {
        correct++;
      }
    }

    final percent = widget.questions.isEmpty
        ? 100
        : ((correct / widget.questions.length) * 100).toInt();

    setState(() {
      _submitted = true;
      _scorePercent = percent;
    });

    widget.progress.recordQuiz(widget.subjectId, percent);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Quiz'),
        actions: [
          if (widget.timeLimitSeconds != null && !_submitted)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_secondsRemaining}s',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                    fontSize: 14,
                  ),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.fact_check_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Concept Verification: Test your understanding and solidify key insights.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            for (int qIdx = 0; qIdx < widget.questions.length; qIdx++) ...[
              _buildQuestionCard(qIdx, widget.questions[qIdx]),
              const SizedBox(height: 16),
            ],

            if (!_submitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('practiverse-quiz-submit'),
                  onPressed: _selectedAnswers.length < widget.questions.length
                      ? null
                      : _submitQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Submit Quiz'),
                ),
              )
            else
              _buildResultSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, DiagnosticQuizQuestion q) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1} of ${widget.questions.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              q.question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: _selectedAnswers[index],
              onChanged: _submitted
                  ? (val) {}
                  : (val) {
                      setState(() {
                        if (val != null) {
                          _selectedAnswers[index] = val;
                        }
                      });
                    },
              child: Column(
                children: List.generate(q.options.length, (optIdx) {
                  final text = q.options[optIdx];
                  Color? tileColor;

                  if (_submitted) {
                    if (optIdx == q.correctIndex) {
                      tileColor = const Color(0xFFDCFCE7);
                    } else if (optIdx == _selectedAnswers[index]) {
                      tileColor = const Color(0xFFFEE2E2);
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Material(
                      color: tileColor ?? Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedAnswers[index] == optIdx
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: RadioListTile<int>(
                          value: optIdx,
                          dense: true,
                          title: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_submitted) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Explanation: ${q.explanation}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultSummary() {
    final passed = _scorePercent >= 70;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: passed ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passed ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.verified_rounded : Icons.info_rounded,
                color: passed
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Quiz Complete: $_scorePercent%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: passed
                      ? const Color(0xFF166534)
                      : const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            passed
                ? 'Excellent retention! Your conceptual foundations are sound.'
                : 'Good effort! Review the explanations above to reinforce misconceptions.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Finish Quiz & Return'),
            ),
          ),
        ],
      ),
    );
  }
}
