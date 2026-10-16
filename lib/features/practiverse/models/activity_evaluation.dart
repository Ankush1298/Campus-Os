/// Represents the evaluated result of a student's experimental trial, prediction,
/// or simulation calculation.
class ActivityEvaluationResult {
  final bool isCorrect;
  final double? predictedValue;
  final double actualValue;
  final double tolerance;
  final String feedback;
  final String? misconceptionKey;
  final String? misconceptionExplanation;
  final List<String> stepByStepDerivation;
  final bool requiresRecovery;

  const ActivityEvaluationResult({
    required this.isCorrect,
    this.predictedValue,
    required this.actualValue,
    required this.tolerance,
    required this.feedback,
    this.misconceptionKey,
    this.misconceptionExplanation,
    required this.stepByStepDerivation,
    this.requiresRecovery = false,
  });

  /// Evaluates numeric predictions with a given percentage or absolute tolerance.
  factory ActivityEvaluationResult.evaluateNumeric({
    required double? prediction,
    required double expected,
    double tolerancePercent = 0.05,
    required String unit,
    String? formulaName,
    Map<String, String>? commonMisconceptions,
  }) {
    if (prediction == null || prediction.isNaN || prediction.isInfinite) {
      return ActivityEvaluationResult(
        isCorrect: false,
        predictedValue: prediction,
        actualValue: expected,
        tolerance: 0,
        feedback: 'Please enter a valid numeric prediction.',
        stepByStepDerivation: ['Expected $expected $unit using $formulaName.'],
      );
    }

    final double allowedDiff = (expected.abs() * tolerancePercent).clamp(
      0.01,
      1000.0,
    );
    final double diff = (prediction - expected).abs();
    final bool match = diff <= allowedDiff;

    String? misconception;
    String? explanation;

    if (!match && commonMisconceptions != null) {
      for (final entry in commonMisconceptions.entries) {
        misconception = entry.key;
        explanation = entry.value;
        break;
      }
    }

    return ActivityEvaluationResult(
      isCorrect: match,
      predictedValue: prediction,
      actualValue: expected,
      tolerance: allowedDiff,
      feedback: match
          ? 'Accurate prediction! Your value ($prediction $unit) is within ±${(tolerancePercent * 100).toInt()}% of the expected $expected $unit.'
          : 'Discrepancy detected: Your prediction was $prediction $unit, but the theoretical model yields $expected $unit.',
      misconceptionKey: match ? null : misconception,
      misconceptionExplanation: match ? null : explanation,
      stepByStepDerivation: [
        'Theoretical formula: $formulaName',
        'Calculated exact value: ${expected.toStringAsFixed(3)} $unit',
        'Allowed tolerance: ±${allowedDiff.toStringAsFixed(3)} $unit',
        if (!match && explanation != null) 'Key takeaway: $explanation',
      ],
    );
  }
}
