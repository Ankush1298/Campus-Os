import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/generated_practical.dart';
import '../../models/practical_activity.dart';
import '../../widgets/line_chart.dart';

enum _Phase { theory, practical, quiz }

/// Runs a generated lesson: 1) THEORY, 2) a PRACTICAL simulation graded by the app, 3) a QUIZ only when the
/// practical was failed (then the student retries the practical with fresh values / order).
///
/// Practicals: a formula exercise (sliders + graph, answer computed on the device), a decision scenario
/// (scored per round), or, for lessons built from pasted notes, a recall exercise.
class GeneratedSimulation extends StatefulWidget {
  final PracticalActivity activity;
  final VoidCallback onLifeDeducted;
  final VoidCallback onUnlockHint;
  final VoidCallback onTriggerRecovery;
  final VoidCallback onCompleted;
  final int currentLives;

  const GeneratedSimulation({
    super.key,
    required this.activity,
    required this.onLifeDeducted,
    required this.onUnlockHint,
    required this.onTriggerRecovery,
    required this.onCompleted,
    required this.currentLives,
  });

  @override
  State<GeneratedSimulation> createState() => _GeneratedSimulationState();
}

class _GeneratedSimulationState extends State<GeneratedSimulation> {
  GeneratedPractical get _g => widget.activity.generated!;
  GeneratedModel? get _m => _g.model;
  GeneratedScenario? get _sc => _g.scenario;

  late _Phase _phase = _g.theory != null ? _Phase.theory : _Phase.practical;
  bool _theoryRead = false;
  bool _passed = false;
  int _attempt = 0;

  // numeric practical
  late Map<String, double> _env = _m?.defaults() ?? {};
  final _answer = TextEditingController();
  bool _evaluated = false;
  bool _correct = false;
  String? _inputError;
  static const double _tolerance = 0.05;

  // scenario practical
  int _round = 0;
  int _score = 0;
  int? _pickedChoice;
  late List<List<int>> _order = _shuffledOrder();

  // recall practical (lessons built from notes)
  late final int _recallCount = (_g.quiz.length + 1) ~/ 2;
  final Map<int, int> _recallPicked = {};
  bool _recallSubmitted = false;
  int _recallScore = 0;

  // remedial quiz
  final Map<int, int> _quizPicked = {};
  bool _quizSubmitted = false;
  int _quizScore = 0;
  bool _needsQuiz = false;

  List<List<int>> _shuffledOrder() {
    final rng = math.Random(_attempt * 7919 + 13);
    return [for (final r in _sc?.rounds ?? const <ScenarioRound>[]) (List<int>.generate(r.choices.length, (i) => i)..shuffle(rng))];
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ flow control
  void _failedPractical() {
    widget.onLifeDeducted();
    widget.onUnlockHint();
    if (widget.currentLives <= 1) widget.onTriggerRecovery();
    setState(() => _needsQuiz = true);
  }

  void _succeeded() {
    setState(() => _passed = true);
    widget.onCompleted();
  }

  void _toQuiz() => setState(() {
        _phase = _Phase.quiz;
        _quizPicked.clear();
        _quizSubmitted = false;
      });

  void _retryPractical() {
    _attempt++;
    final m = _m;
    setState(() {
      _phase = _Phase.practical;
      _needsQuiz = false;
      _evaluated = false;
      _correct = false;
      _inputError = null;
      _answer.clear();
      _round = 0;
      _score = 0;
      _pickedChoice = null;
      _recallPicked.clear();
      _recallSubmitted = false;
      _order = _shuffledOrder();
      if (m != null) _env = _freshValues(m);
    });
  }

  /// New starting values so a retry cannot be passed by reusing the previous answer.
  Map<String, double> _freshValues(GeneratedModel m) {
    final rng = math.Random(_attempt * 104729 + 7);
    return {
      for (final v in m.variables)
        v.name: () {
          final steps = math.max(1, ((v.max - v.min) / v.step).floor());
          return (v.min + v.step * rng.nextInt(steps + 1)).clamp(v.min, v.max).toDouble();
        }(),
    };
  }

  // ------------------------------------------------------------------ shared UI
  Widget _stepper() {
    final steps = _g.theory != null ? ['Theory', 'Practical', 'Quiz if needed'] : ['Practical', 'Quiz if needed'];
    final current = _g.theory != null ? _phase.index : (_phase == _Phase.quiz ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        key: const Key('gen-stepper'),
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: i == current ? const Color(0xFF0E7C86) : (i < current ? const Color(0xFFD0ECEF) : const Color(0xFFE9EEF5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${i + 1}. ${steps[i]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == current ? Colors.white : const Color(0xFF2C3C58))),
                ),
              ),
            ),
            if (i < steps.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _feedback(bool ok, String title, String body, {Key? key}) => Container(
        key: key ?? const Key('gen-feedback'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: ok ? const Color(0xFF166534) : const Color(0xFF991B1B))),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ],
        ),
      );

  Widget _radioQuestion({required String prefix, required GeneratedQuiz q, required int? picked, required bool locked, required ValueChanged<int> onPick, required bool showReview, required String keyBase}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$prefix ${q.question}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.35)),
        RadioGroup<int>(
          groupValue: picked,
          onChanged: (v) {
            if (!locked) onPick(v!);
          },
          child: Column(
            children: [
              for (var o = 0; o < q.options.length; o++)
                RadioListTile<int>(
                  key: Key('$keyBase-o$o'),
                  value: o,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.options[o], style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
        if (showReview && picked != q.correctIndex)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Review: ${q.explanation}', style: const TextStyle(fontSize: 12, color: Color(0xFF9E1C27)))),
        const SizedBox(height: 6),
      ],
    );
  }

  // ------------------------------------------------------------------ phase 1: theory
  Widget _theoryView() {
    final t = _g.theory!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF0E7C86)), SizedBox(width: 8), Text('Learn first: theory', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
                if (t.overview.isNotEmpty) ...[const SizedBox(height: 8), Text(t.overview, key: const Key('gen-theory-overview'), style: const TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w600))],
                for (final s in t.sections) ...[
                  const SizedBox(height: 12),
                  Text(s.heading, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(s.body, style: const TextStyle(fontSize: 13, height: 1.45)),
                ],
              ],
            ),
          ),
        ),
        if (t.keyTerms.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Key terms', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  for (final k in t.keyTerms)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text.rich(TextSpan(children: [TextSpan(text: '${k.term}: ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: k.meaning)]), style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (t.workedExample.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Worked example', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(t.workedExample, style: const TextStyle(fontSize: 13, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('gen-start-practical'),
            onPressed: () {
              _theoryRead = true;
              final hasQuiz = _m != null || _sc != null;
              if (_needsQuiz && hasQuiz) {
                _toQuiz(); // failed the practical: back to the review quiz (fresh answers)
              } else if (_needsQuiz) {
                _retryPractical(); // recall lessons: re-read, then try again
              } else {
                setState(() => _phase = _Phase.practical);
              }
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_needsQuiz ? ((_m != null || _sc != null) ? 'Back to the quiz' : 'Retry the practical') : (_theoryRead ? 'Back to the practical' : 'I have read it: start the practical')),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ phase 2: practical
  Widget _practicalView() {
    if (_passed) {
      return _feedback(true, 'Practical passed', 'You applied the theory correctly. Lesson complete.', key: const Key('gen-passed'));
    }
    if (_m != null) return _numeric(_m!);
    if (_sc != null) return _scenario(_sc!);
    return _recall();
  }

  Widget _afterFailure(String detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _feedback(false, 'Not quite. Time to review.', detail),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('gen-take-quiz'),
              onPressed: _m != null || _sc != null ? _toQuiz : () => setState(() => _phase = _Phase.theory),
              icon: Icon(_m != null || _sc != null ? Icons.quiz_rounded : Icons.menu_book_rounded),
              label: Text(_m != null || _sc != null ? 'Take the review quiz' : 'Re-read the theory, then retry'),
            ),
          ),
        ],
      );

  Widget _numeric(GeneratedModel m) {
    final first = m.variables.first;
    final points = <Offset>[];
    const n = 40;
    for (var i = 0; i <= n; i++) {
      final x = first.min + (first.max - first.min) * i / n;
      final y = m.answer({..._env, first.name: x});
      if (y != null) points.add(Offset(x, y));
    }
    final current = m.answer(_env);
    final canPlot = points.length > 2 && points.every((p) => p.dy >= 0);
    final yMax = canPlot ? _niceCeil(points.map((p) => p.dy).reduce(math.max)) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your task', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 6),
                Text(m.questionFor(_env), key: const Key('gen-question'), style: const TextStyle(fontSize: 13.5, height: 1.4)),
                const SizedBox(height: 10),
                for (final v in m.variables) ...[
                  Text('${v.label}: ${GeneratedModel.fmt(_env[v.name]!)} ${v.unit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Slider(
                    key: Key('gen-slider-${v.name}'),
                    value: _env[v.name]!.clamp(v.min, v.max),
                    min: v.min,
                    max: v.max,
                    divisions: math.max(1, math.min(200, ((v.max - v.min) / v.step).round())),
                    label: GeneratedModel.fmt(_env[v.name]!),
                    onChanged: _needsQuiz
                        ? null
                        : (x) => setState(() {
                              _env = {..._env, v.name: x};
                              _evaluated = false;
                              _inputError = null;
                            }),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: canPlot
                ? LabeledLineChart(
                    key: const Key('gen-graph'),
                    title: 'Simulation: ${m.resultName} vs ${first.label}',
                    xLabel: '${first.label} (${first.unit})',
                    yLabel: '${m.resultName} (${m.resultUnit})',
                    xMax: first.max,
                    yMax: yMax,
                    series: [ChartSeries(label: '${m.resultName} from ${m.expression}', points: points, color: const Color(0xFF0E7C86))],
                    marker: current == null ? null : Offset(_env[first.name]!, current),
                    caption: 'Drawn from the formula with the other values at their current setting. Move a slider and watch the red dot (your current setting) move along the curve.',
                  )
                : Text('The graph is hidden because this formula gives negative values here. Use the sliders and the formula ${m.expression}.', style: const TextStyle(fontSize: 12.5, color: Color(0xFF46566F))),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formula: ${m.formulaLabel.isEmpty ? m.expression : m.formulaLabel}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                Text('What is the ${m.resultName.toLowerCase()} for the values above? (${m.resultUnit.isEmpty ? 'no unit' : m.resultUnit})', style: const TextStyle(fontSize: 13, color: Color(0xFF46566F))),
                const SizedBox(height: 10),
                if (_needsQuiz)
                  _afterFailure('${m.resultName} = ${m.expression} = ${GeneratedModel.fmt(current ?? double.nan)} ${m.resultUnit}\n${m.explanation}')
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('practiverse-prediction-input'),
                          controller: _answer,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          decoration: InputDecoration(hintText: 'e.g. 2.5', suffixText: m.resultUnit, errorText: _inputError),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(key: const Key('practiverse-check'), onPressed: _verifyNumber, child: const Text('Verify')),
                    ],
                  ),
                if (_evaluated && _correct) ...[
                  const SizedBox(height: 12),
                  _feedback(true, 'Correct', '${m.resultName} = ${m.expression} = ${GeneratedModel.fmt(current ?? double.nan)} ${m.resultUnit}\n${m.explanation}'),
                ],
                if (_g.reflection.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Reflect (not graded):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  for (final r in _g.reflection) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $r', style: const TextStyle(fontSize: 12.5))),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _verifyNumber() {
    final m = _m!;
    final x = double.tryParse(_answer.text.trim().replaceAll(',', '.'));
    if (x == null || !x.isFinite) {
      setState(() => _inputError = 'Enter a number (for example 2.5).');
      return;
    }
    final expected = m.answer(_env);
    if (expected == null) {
      setState(() => _inputError = 'These values give an undefined result. Move a slider.');
      return;
    }
    final tol = expected.abs() < 1e-9 ? 0.01 : expected.abs() * _tolerance;
    final ok = (x - expected).abs() <= tol;
    setState(() {
      _inputError = null;
      _evaluated = true;
      _correct = ok;
    });
    ok ? _succeeded() : _failedPractical();
  }

  Widget _scenario(GeneratedScenario sc) {
    final finished = _round >= sc.rounds.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.psychology_alt_rounded, size: 18, color: Color(0xFF0E7C86)), SizedBox(width: 8), Text('Scenario simulation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
            const SizedBox(height: 8),
            Text(sc.setup, key: const Key('gen-scenario-setup'), style: const TextStyle(fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            if (!finished) ...[
              Text('Round ${_round + 1} of ${sc.rounds.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0E7C86))),
              const SizedBox(height: 4),
              Text(sc.rounds[_round].situation, key: const Key('gen-situation'), style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final idx in _order[_round])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: Key('gen-choice-$_round-$idx'),
                      onPressed: _pickedChoice != null ? null : () => setState(() {
                            _pickedChoice = idx;
                            _score += sc.rounds[_round].choices[idx].score;
                          }),
                      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      child: Text(sc.rounds[_round].choices[idx].text, style: const TextStyle(fontSize: 13, height: 1.35), textAlign: TextAlign.left),
                    ),
                  ),
                ),
              if (_pickedChoice != null) ...[
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final c = sc.rounds[_round].choices[_pickedChoice!];
                  return _feedback(c.score == 2, c.score == 2 ? 'Best decision' : (c.score == 1 ? 'Partly right' : 'Poor decision'), c.feedback, key: const Key('gen-choice-feedback'));
                }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('gen-next-round'),
                    onPressed: () {
                      setState(() {
                        _round++;
                        _pickedChoice = null;
                      });
                      if (_round >= sc.rounds.length) {
                        (_score / sc.maxScore >= GeneratedScenario.passFraction) ? _succeeded() : _failedPractical();
                      }
                    },
                    child: Text(_round + 1 >= sc.rounds.length ? 'See my result' : 'Next round'),
                  ),
                ),
              ],
            ] else ...[
              Text('Your score: $_score / ${sc.maxScore}', key: const Key('gen-scenario-score'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),
              if (_needsQuiz) _afterFailure('You need at least ${(GeneratedScenario.passFraction * 100).round()}% to pass. Review the theory with a short quiz, then retry the scenario.'),
            ],
            if (_g.reflection.isNotEmpty && finished) ...[
              const SizedBox(height: 12),
              const Text('Reflect (not graded):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              for (final r in _g.reflection) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $r', style: const TextStyle(fontSize: 12.5))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recall() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_g.task, key: const Key('gen-task'), style: const TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (var i = 0; i < _recallCount; i++)
              _radioQuestion(prefix: '${i + 1}.', q: _g.quiz[i], picked: _recallPicked[i], locked: _recallSubmitted, onPick: (v) => setState(() => _recallPicked[i] = v), showReview: _recallSubmitted, keyBase: 'gen-q$i'),
            if (_inputError != null) Text(_inputError!, style: const TextStyle(color: Color(0xFF9E1C27), fontSize: 12.5)),
            if (_recallSubmitted && !_correct) _afterFailure('Score $_recallScore / $_recallCount. You need at least 60%.')
            else if (!_recallSubmitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('practiverse-check'),
                  onPressed: () {
                    if (_recallPicked.length < _recallCount) {
                      setState(() => _inputError = 'Answer every question first.');
                      return;
                    }
                    var sc = 0;
                    for (var i = 0; i < _recallCount; i++) {
                      if (_recallPicked[i] == _g.quiz[i].correctIndex) sc++;
                    }
                    final pass = sc / _recallCount >= 0.6;
                    setState(() {
                      _inputError = null;
                      _recallSubmitted = true;
                      _recallScore = sc;
                      _correct = pass;
                    });
                    pass ? _succeeded() : _failedPractical();
                  },
                  child: const Text('Submit answers'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ phase 3: remedial quiz
  Widget _quizView() {
    final quiz = _g.quiz;
    final passed = _quizSubmitted && _quizScore / quiz.length >= 0.6;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.quiz_rounded, size: 18, color: Color(0xFFD98A00)), SizedBox(width: 8), Text('Review quiz', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
            const SizedBox(height: 4),
            const Text('You missed the practical, so check the theory first. Pass this quiz (60%) to retry the practical with new values.', style: TextStyle(fontSize: 12.5, color: Color(0xFF46566F))),
            const SizedBox(height: 10),
            for (var i = 0; i < quiz.length; i++)
              _radioQuestion(prefix: '${i + 1}.', q: quiz[i], picked: _quizPicked[i], locked: _quizSubmitted, onPick: (v) => setState(() => _quizPicked[i] = v), showReview: _quizSubmitted, keyBase: 'gen-rq$i'),
            if (_inputError != null) Text(_inputError!, style: const TextStyle(color: Color(0xFF9E1C27), fontSize: 12.5)),
            if (!_quizSubmitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('gen-submit-quiz'),
                  onPressed: () {
                    if (_quizPicked.length < quiz.length) {
                      setState(() => _inputError = 'Answer every question first.');
                      return;
                    }
                    var sc = 0;
                    for (var i = 0; i < quiz.length; i++) {
                      if (_quizPicked[i] == quiz[i].correctIndex) sc++;
                    }
                    setState(() {
                      _inputError = null;
                      _quizSubmitted = true;
                      _quizScore = sc;
                    });
                  },
                  child: const Text('Submit quiz'),
                ),
              )
            else ...[
              _feedback(passed, passed ? 'Quiz passed: $_quizScore / ${quiz.length}' : 'Quiz score $_quizScore / ${quiz.length}', passed ? 'Good. Now retry the practical with new values.' : 'Read the reviews above, re-read the theory and try the quiz again.', key: const Key('gen-quiz-result')),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('gen-after-quiz'),
                  onPressed: passed
                      ? _retryPractical
                      : () => setState(() {
                            if (_g.theory != null) {
                              _phase = _Phase.theory;
                            } else {
                              _quizPicked.clear();
                              _quizSubmitted = false;
                            }
                          }),
                  child: Text(passed ? 'Retry the practical' : (_g.theory != null ? 'Re-read the theory' : 'Try the quiz again')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * p >= v) return m * p;
    }
    return 10 * p;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepper(),
        if (_phase == _Phase.theory) _theoryView(),
        if (_phase == _Phase.practical) _practicalView(),
        if (_phase == _Phase.quiz) _quizView(),
      ],
    );
  }
}
