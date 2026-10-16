enum ActivityKind {
  physicsOhmsLaw,
  statisticsDataAnalysis,
  chemistryDilution,
  codingChallenge,
  externalVirtualLab,
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
  });
}
