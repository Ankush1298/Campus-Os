import 'generated_practical.dart';

enum ActivityKind {
  physicsOhmsLaw,
  statisticsDataAnalysis,
  chemistryDilution,
  codingChallenge,
  externalVirtualLab,

  /// A practical generated for an arbitrary topic (see GeneratedPractical).
  generated,
}

class RecoveryQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String misconceptionTarget;

  const RecoveryQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.misconceptionTarget,
  });
}

class DiagnosticQuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const DiagnosticQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class ExternalLabResource {
  final String title;
  final String url;
  final String provider;
  final String description;

  const ExternalLabResource({
    required this.title,
    required this.url,
    required this.provider,
    required this.description,
  });
}

class PracticalActivity {
  final String id;
  final String subjectId;
  final String title;
  final String conceptTested;
  final String difficulty;
  final String objective;
  final ActivityKind kind;
  final String formulaNotation;
  final bool isVirtualSimulation;
  final List<String> hints;
  final List<RecoveryQuestion> recoveryQuestions;
  final List<DiagnosticQuizQuestion> diagnosticQuizQuestions;
  final ExternalLabResource? externalLab;
  final GeneratedPractical? generated;

  const PracticalActivity({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.conceptTested,
    required this.difficulty,
    required this.objective,
    required this.kind,
    required this.formulaNotation,
    this.isVirtualSimulation = true,
    required this.hints,
    required this.recoveryQuestions,
    required this.diagnosticQuizQuestions,
    this.externalLab,
    this.generated,
  });
}

extension GeneratedPracticalActivity on GeneratedPractical {
  /// Adapts a generated practical to the existing workspace (lives, hints, recovery question, verification quiz).
  PracticalActivity toActivity() {
    return PracticalActivity(
      id: id,
      subjectId: subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
      title: title,
      conceptTested: concepts.join(' | '),
      difficulty: difficulty,
      objective: objective,
      kind: ActivityKind.generated,
      formulaNotation: model?.formulaLabel.isNotEmpty == true ? model!.formulaLabel : subject,
      hints: hints,
      recoveryQuestions: [
        RecoveryQuestion(
          question: recovery.question,
          options: recovery.options,
          correctIndex: recovery.correctIndex,
          explanation: recovery.explanation,
          misconceptionTarget: 'generated',
        ),
      ],
      // Generated lessons use the quiz only as remediation after a failed practical (inside the simulation),
      // never as a second exam after success.
      diagnosticQuizQuestions: const [],
      generated: this,
    );
  }
}
