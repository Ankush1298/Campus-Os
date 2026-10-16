/// Tracks a student's session state, remaining lives, completed simulations,
/// resolved misconceptions, and verification quiz scores across subjects.
class StudentProgress {
  int lives;
  final Set<String> completedActivityIds;
  final List<String> resolvedMisconceptions;
  final Map<String, int> quizScores; // subjectId -> percentage score
  int hintsUsed;
  int trialsConducted;

  StudentProgress({
    this.lives = 3,
    Set<String>? completedActivityIds,
    List<String>? resolvedMisconceptions,
    Map<String, int>? quizScores,
    this.hintsUsed = 0,
    this.trialsConducted = 0,
  }) : completedActivityIds = completedActivityIds ?? <String>{},
       resolvedMisconceptions = resolvedMisconceptions ?? <String>[],
       quizScores = quizScores ?? <String, int>{};

  bool get isGameOver => lives <= 0;
  bool get canRecover => lives <= 0;

  void deductLife() {
    if (lives > 0) {
      lives--;
    }
  }

  void restoreLife() {
    if (lives < 3) {
      lives++;
    }
  }

  void resetLives() {
    lives = 3;
  }

  void markCompleted(String activityId) {
    completedActivityIds.add(activityId);
  }

  void resolveMisconception(String misconception) {
    if (!resolvedMisconceptions.contains(misconception)) {
      resolvedMisconceptions.add(misconception);
    }
  }

  void recordQuiz(String subjectId, int scorePercent) {
    quizScores[subjectId] = scorePercent;
  }
}
