import 'practical_subject.dart';
import 'practical_activity.dart';

/// Represents the output of analyzing raw text, notes, or syllabus content.
class TopicIntakeResult {
  final String queryText;
  final PracticalSubject matchedSubject;
  final List<String> extractedKeyConcepts;
  final List<PracticalActivity> recommendedActivities;
  final String pedagogicalGuidance;
  final List<ExternalLabResource> externalResources;

  const TopicIntakeResult({
    required this.queryText,
    required this.matchedSubject,
    required this.extractedKeyConcepts,
    required this.recommendedActivities,
    required this.pedagogicalGuidance,
    required this.externalResources,
  });
}
