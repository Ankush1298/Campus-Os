import 'practical_subject.dart';
import 'practical_activity.dart';

/// One line / topic found in the student's text and what PractiVerse can offer for it.
class TopicMapping {
  final String topic;
  final PracticalActivity? activity; // null: no practical exists for this topic yet
  final List<String> matchedTerms;
  const TopicMapping({required this.topic, this.activity, this.matchedTerms = const []});

  bool get hasPractical => activity != null;
}

/// Output of analysing raw text, notes, or a syllabus. Honest about misses: [matched] is false when no
/// practical fits, and [unsupportedTopics] lists recognised topics that have no practical yet.
class TopicIntakeResult {
  final String queryText;
  final bool matched;
  final PracticalSubject matchedSubject;
  final List<PracticalSubject> otherSubjects;
  final List<String> extractedKeyConcepts;
  final List<PracticalActivity> recommendedActivities;
  final List<TopicMapping> topicMappings;
  final List<String> unsupportedTopics;
  final String pedagogicalGuidance;
  final List<ExternalLabResource> externalResources;

  const TopicIntakeResult({
    required this.queryText,
    required this.matchedSubject,
    required this.extractedKeyConcepts,
    required this.recommendedActivities,
    required this.pedagogicalGuidance,
    required this.externalResources,
    this.matched = true,
    this.otherSubjects = const [],
    this.topicMappings = const [],
    this.unsupportedTopics = const [],
  });
}
