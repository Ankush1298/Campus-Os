import '../engine/formula.dart';

class GeneratedVariable {
  final String name, label, unit;
  final double min, max, step, defaultValue;
  const GeneratedVariable({required this.name, required this.label, required this.unit, required this.min, required this.max, required this.step, required this.defaultValue});

  factory GeneratedVariable.fromJson(Map<String, dynamic> j) => GeneratedVariable(
        name: j['name'] as String,
        label: j['label'] as String? ?? j['name'] as String,
        unit: j['unit'] as String? ?? '',
        min: (j['min'] as num).toDouble(),
        max: (j['max'] as num).toDouble(),
        step: (j['step'] as num).toDouble(),
        defaultValue: (j['default'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'name': name, 'label': label, 'unit': unit, 'min': min, 'max': max, 'step': step, 'default': defaultValue};
}

/// A calculation the student can do and the app can check by itself (the answer is computed on the device from the formula).
class GeneratedModel {
  final String formulaLabel, expression, resultName, resultUnit, question, explanation;
  final List<GeneratedVariable> variables;
  final Formula formula;

  GeneratedModel._({required this.formulaLabel, required this.expression, required this.resultName, required this.resultUnit, required this.question, required this.explanation, required this.variables, required this.formula});

  /// Null when the model cannot be trusted (bad formula, undefined over its own range, missing placeholders).
  static GeneratedModel? tryParse(Map<String, dynamic>? j) {
    if (j == null) return null;
    try {
      final vars = [for (final v in (j['variables'] as List)) GeneratedVariable.fromJson(Map<String, dynamic>.from(v as Map))];
      if (vars.isEmpty || vars.length > 4) return null;
      final names = {for (final v in vars) v.name};
      if (names.length != vars.length) return null;
      for (final v in vars) {
        if (!(v.min < v.max) || v.step <= 0 || v.defaultValue < v.min || v.defaultValue > v.max) return null;
      }
      final f = Formula.parse(j['expression'] as String, names);
      final question = j['question'] as String;
      if (!names.every((n) => question.contains('{$n}'))) return null;
      // every corner of the declared ranges must give a finite answer
      var corners = <Map<String, double>>[{}];
      for (final v in vars) {
        corners = [for (final c in corners) for (final x in [v.min, v.defaultValue, v.max]) {...c, v.name: x}];
      }
      if (corners.any((c) => f.evaluate(c) == null)) return null;
      return GeneratedModel._(
        formulaLabel: j['formula_label'] as String? ?? '',
        expression: j['expression'] as String,
        resultName: j['result_name'] as String? ?? 'Result',
        resultUnit: j['result_unit'] as String? ?? '',
        question: question,
        explanation: j['explanation'] as String? ?? '',
        variables: vars,
        formula: f,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, double> defaults() => {for (final v in variables) v.name: v.defaultValue};
  double? answer(Map<String, double> env) => formula.evaluate(env);

  String questionFor(Map<String, double> env) {
    var q = question;
    for (final v in variables) {
      final x = env[v.name] ?? v.defaultValue;
      q = q.replaceAll('{${v.name}}', fmt(x));
    }
    return q;
  }

  static String fmt(double x) => x == x.roundToDouble() && x.abs() < 1e9 ? x.toStringAsFixed(0) : x.toStringAsPrecision(4).replaceFirst(RegExp(r'\.?0+$'), '');

  Map<String, dynamic> toJson() => {
        'formula_label': formulaLabel, 'expression': expression, 'result_name': resultName, 'result_unit': resultUnit,
        'variables': [for (final v in variables) v.toJson()], 'question': question, 'explanation': explanation,
      };
}

class GeneratedQuiz {
  final String question, explanation;
  final List<String> options;
  final int correctIndex;
  const GeneratedQuiz({required this.question, required this.options, required this.correctIndex, required this.explanation});

  static GeneratedQuiz? tryParse(Object? j) {
    if (j is! Map) return null;
    final opts = (j['options'] as List?)?.whereType<String>().toList() ?? const [];
    final idx = j['correct_index'];
    if (opts.length != 4 || idx is! int || idx < 0 || idx > 3 || opts.toSet().length != 4) return null;
    return GeneratedQuiz(question: j['question'] as String? ?? '', options: opts, correctIndex: idx, explanation: j['explanation'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'question': question, 'options': options, 'correct_index': correctIndex, 'explanation': explanation};
}

class TheorySection {
  final String heading, body;
  const TheorySection(this.heading, this.body);
  Map<String, dynamic> toJson() => {'heading': heading, 'body': body};
}

class KeyTerm {
  final String term, meaning;
  const KeyTerm(this.term, this.meaning);
  Map<String, dynamic> toJson() => {'term': term, 'meaning': meaning};
}

/// The "learn first" part of a lesson.
class GeneratedTheory {
  final String overview, workedExample;
  final List<TheorySection> sections;
  final List<KeyTerm> keyTerms;
  const GeneratedTheory({required this.overview, required this.sections, required this.keyTerms, required this.workedExample});

  static GeneratedTheory? tryParse(Object? j) {
    if (j is! Map) return null;
    final sections = [
      for (final s in (j['sections'] as List? ?? const []))
        if (s is Map && s['heading'] is String && s['body'] is String && (s['body'] as String).trim().isNotEmpty) TheorySection(s['heading'] as String, s['body'] as String),
    ];
    if (sections.isEmpty) return null;
    return GeneratedTheory(
      overview: j['overview'] as String? ?? '',
      sections: sections,
      keyTerms: [
        for (final k in (j['key_terms'] as List? ?? const []))
          if (k is Map && k['term'] is String && k['meaning'] is String) KeyTerm(k['term'] as String, k['meaning'] as String),
      ],
      workedExample: j['worked_example'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'overview': overview, 'sections': [for (final s in sections) s.toJson()], 'key_terms': [for (final k in keyTerms) k.toJson()], 'worked_example': workedExample};
}

class ScenarioChoice {
  final String text, feedback;
  final int score; // 2 best, 1 partly right, 0 wrong
  const ScenarioChoice({required this.text, required this.score, required this.feedback});
  Map<String, dynamic> toJson() => {'text': text, 'score': score, 'feedback': feedback};
}

class ScenarioRound {
  final String situation;
  final List<ScenarioChoice> choices;
  const ScenarioRound({required this.situation, required this.choices});
  Map<String, dynamic> toJson() => {'situation': situation, 'choices': [for (final c in choices) c.toJson()]};
}

/// A decision simulation for topics without a formula (law, history, medicine, management, languages...).
class GeneratedScenario {
  final String setup;
  final List<ScenarioRound> rounds;
  const GeneratedScenario({required this.setup, required this.rounds});

  static const double passFraction = 0.6;

  /// Null unless every round has 2-4 choices with scores 0-2 and exactly one best choice (the same rule the server applies).
  static GeneratedScenario? tryParse(Object? j) {
    try {
      if (j is! Map) return null;
      final rounds = <ScenarioRound>[];
      for (final r in (j['rounds'] as List)) {
        final choices = [
          for (final c in (r['choices'] as List)) ScenarioChoice(text: c['text'] as String, score: (c['score'] as num).toInt(), feedback: c['feedback'] as String),
        ];
        if (choices.length < 2 || choices.length > 4 || choices.any((c) => c.score < 0 || c.score > 2) || choices.where((c) => c.score == 2).length != 1) return null;
        rounds.add(ScenarioRound(situation: r['situation'] as String, choices: choices));
      }
      if (rounds.length < 2) return null;
      return GeneratedScenario(setup: j['setup'] as String, rounds: rounds);
    } catch (_) {
      return null;
    }
  }

  int get maxScore => rounds.length * 2;
  Map<String, dynamic> toJson() => {'setup': setup, 'rounds': [for (final r in rounds) r.toJson()]};
}

/// Where the practical came from. The UI always shows this: students must know what they are trusting.
enum GeneratedSource { ai, notes }

class GeneratedPractical {
  final String id, title, subject, difficulty, objective, task, inputs, expected, validation;
  final List<String> steps, concepts, hints, reflection;
  final GeneratedTheory? theory;
  final GeneratedModel? model;
  final GeneratedScenario? scenario;
  final List<GeneratedQuiz> quiz;
  final GeneratedQuiz recovery;
  final GeneratedSource source;
  final String sourceText;
  final DateTime createdAt;

  const GeneratedPractical({
    required this.id, required this.title, required this.subject, required this.difficulty, required this.objective,
    required this.task, required this.steps, required this.inputs, required this.expected, required this.validation,
    required this.concepts, required this.model, required this.quiz, this.theory, this.scenario, required this.hints, required this.recovery,
    required this.reflection, required this.source, required this.sourceText, required this.createdAt,
  });

  String get sourceLabel => source == GeneratedSource.ai
      ? 'AI-generated from your topic. Facts, scenario feedback and quiz answers come from the model: check them against your course material.'
      : 'Built from your own notes (no AI): every question and answer comes from the text you pasted.';

  /// How the lesson runs: theory first, then the practical, and the quiz only if the practical is failed.
  static const String flowNote = 'Lesson flow: 1) read the theory, 2) do the practical, 3) take a short quiz only if you miss the practical, then retry it.';

  /// The kind of practical this lesson contains.
  String get practicalKind => model != null ? 'calculation' : (scenario != null ? 'scenario' : 'recall');

  /// Parses and RE-VALIDATES a server / stored practical. Throws FormatException when it is not usable.
  static GeneratedPractical fromJson(Map<String, dynamic> j, {required String sourceText, String? id, DateTime? createdAt}) {
    List<String> strs(String k) => ((j[k] as List?) ?? const []).whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    final quiz = [for (final q in (j['quiz'] as List? ?? const [])) ?GeneratedQuiz.tryParse(q)];
    final recovery = GeneratedQuiz.tryParse(j['recovery']);
    final steps = strs('steps'), hints = strs('hints');
    if (quiz.length < 3 || recovery == null || steps.length < 3 || hints.length < 2) {
      throw const FormatException('The generated practical was incomplete.');
    }
    return GeneratedPractical(
      id: id ?? j['id'] as String? ?? 'gen-${DateTime.now().microsecondsSinceEpoch}',
      title: j['title'] as String? ?? 'Custom practical',
      subject: j['subject'] as String? ?? 'General',
      difficulty: j['difficulty'] as String? ?? 'Intermediate',
      objective: j['objective'] as String? ?? '',
      task: j['task'] as String? ?? '',
      steps: steps,
      inputs: j['inputs'] as String? ?? '',
      expected: j['expected'] as String? ?? '',
      validation: j['validation'] as String? ?? '',
      concepts: strs('concepts'),
      theory: GeneratedTheory.tryParse(j['theory']),
      model: GeneratedModel.tryParse(j['model'] == null ? null : Map<String, dynamic>.from(j['model'] as Map)),
      scenario: GeneratedModel.tryParse(j['model'] == null ? null : Map<String, dynamic>.from(j['model'] as Map)) != null ? null : GeneratedScenario.tryParse(j['scenario']),
      quiz: quiz,
      hints: hints,
      recovery: recovery,
      reflection: strs('reflection'),
      source: (j['generated_by'] == 'notes') ? GeneratedSource.notes : GeneratedSource.ai,
      sourceText: sourceText,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'subject': subject, 'difficulty': difficulty, 'objective': objective, 'task': task,
        'steps': steps, 'inputs': inputs, 'expected': expected, 'validation': validation, 'concepts': concepts,
        'theory': theory?.toJson(), 'scenario': scenario?.toJson(), 'model': model?.toJson(), 'quiz': [for (final q in quiz) q.toJson()], 'hints': hints, 'recovery': recovery.toJson(),
        'reflection': reflection, 'generated_by': source == GeneratedSource.ai ? 'ai' : 'notes', 'source_text': sourceText,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static GeneratedPractical fromStored(Map<String, dynamic> j) => fromJson(j, sourceText: j['source_text'] as String? ?? '', id: j['id'] as String?, createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''));
}
