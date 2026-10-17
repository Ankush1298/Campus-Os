import 'dart:math' as math;

import '../models/generated_practical.dart';

/// Builds a practical from the student's OWN pasted notes, with no AI and no network: fill-in-the-blank
/// questions whose answers are words taken from the text, with distractors taken from the same text.
/// It works for any subject because the content is the student's, but it needs real notes (several sentences);
/// a bare topic title cannot be turned into questions without a language model.
class LocalPracticalBuilder {
  static const int minQuestions = 4;
  static const int maxQuestions = 7;

  static const Set<String> _stop = {
    'about', 'above', 'after', 'again', 'against', 'also', 'always', 'among', 'because', 'been', 'before', 'being',
    'between', 'both', 'cannot', 'could', 'does', 'doing', 'during', 'each', 'either', 'every', 'from', 'further',
    'have', 'having', 'here', 'however', 'into', 'itself', 'just', 'like', 'many', 'might', 'more', 'most', 'much',
    'must', 'only', 'other', 'others', 'over', 'same', 'should', 'since', 'some', 'such', 'than', 'that', 'their',
    'them', 'then', 'there', 'these', 'they', 'this', 'those', 'through', 'under', 'until', 'upon', 'very', 'were',
    'what', 'when', 'where', 'which', 'while', 'will', 'with', 'within', 'without', 'would', 'your', 'usually',
    'known', 'using', 'used', 'uses', 'make', 'makes', 'made', 'often', 'order', 'can', 'its',
  };

  /// True when [text] has enough sentences to build at least [minQuestions] questions.
  static bool canBuild(String text) => fromNotes(text) != null;

  static GeneratedPractical? fromNotes(String text) {
    final clean = text.replaceAll('\r', '').trim();
    if (clean.length < 120) return null;

    final title = _title(clean);
    final sentences = <String>[];
    for (final raw in clean.split(RegExp(r'(?<=[.!?])\s+|\n+'))) {
      final s = raw.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*'), '').trim();
      if (s.length >= 35 && s.length <= 260 && !sentences.contains(s) && RegExp(r'[A-Za-z]{3,}\s+[A-Za-z]{3,}').hasMatch(s)) sentences.add(s);
    }
    if (sentences.length < minQuestions) return null;

    final freq = <String, int>{};
    for (final w in RegExp(r"[A-Za-z][A-Za-z\-]{3,}").allMatches(clean.toLowerCase())) {
      freq[w[0]!] = (freq[w[0]!] ?? 0) + 1;
    }

    final used = <String>{};
    final built = <({String sentence, String answer})>[];
    for (final s in sentences) {
      final words = RegExp(r"[A-Za-z][A-Za-z\-]{4,}").allMatches(s).toList();
      String? best;
      var bestScore = -999.0;
      for (final m in words) {
        final w = m[0]!;
        final lw = w.toLowerCase();
        if (_stop.contains(lw) || used.contains(lw)) continue;
        final capitalMid = m.start > 0 && w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase();
        final score = w.length + (capitalMid ? 4 : 0) - 2.0 * ((freq[lw] ?? 1) - 1);
        if (score > bestScore) {
          bestScore = score;
          best = w;
        }
      }
      if (best != null) {
        used.add(best.toLowerCase());
        built.add((sentence: s, answer: best));
      }
    }
    if (built.length < minQuestions) return null;

    final chosen = built.take(maxQuestions + 1).toList();
    final rng = math.Random(text.hashCode);
    GeneratedQuiz make(({String sentence, String answer}) item) {
      final blank = item.sentence.replaceFirst(RegExp('\\b${RegExp.escape(item.answer)}\\b', caseSensitive: false), '_____');
      final pool = [for (final o in chosen) if (o.answer.toLowerCase() != item.answer.toLowerCase()) o.answer]
        ..sort((a, b) => (a.length - item.answer.length).abs().compareTo((b.length - item.answer.length).abs()));
      final distractors = pool.take(3).toList();
      final options = [...distractors, item.answer]..shuffle(rng);
      return GeneratedQuiz(
        question: 'Fill in the blank from your notes: $blank',
        options: options,
        correctIndex: options.indexOf(item.answer),
        explanation: 'Your notes say: "${item.sentence}"',
      );
    }

    final quizzes = [for (final c in chosen) make(c)];
    if (quizzes.any((q) => q.options.toSet().length != 4)) return null;
    final recovery = quizzes.removeLast();
    // Theory = the student's own notes, grouped into short readable sections.
    final groups = <List<String>>[];
    for (var i = 0; i < sentences.length; i += 3) {
      groups.add(sentences.skip(i).take(3).toList());
    }
    final theory = GeneratedTheory(
      overview: 'These are your own notes on "$title". Read them, then complete the recall practical.',
      sections: [for (var i = 0; i < groups.length && i < 5; i++) TheorySection('Part ${i + 1}', groups[i].join(' '))],
      keyTerms: [for (final b in built.take(6)) KeyTerm(b.answer, 'from: "${b.sentence.length > 90 ? '${b.sentence.substring(0, 90)}...' : b.sentence}"')],
      workedExample: '',
    );
    final first = built.first.answer;
    return GeneratedPractical(
      id: 'gen-notes-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Recall check: $title',
      subject: 'Your notes',
      difficulty: 'Beginner',
      objective: 'Check that you can recall the key ideas in your own notes on "$title".',
      task: 'Complete each sentence from your notes by choosing the missing word.',
      steps: const [
        'Read each sentence and think of the missing word before looking at the options.',
        'Choose the option that completes the sentence the way your notes do.',
        'Submit, then read the review of anything you missed and try again.',
      ],
      inputs: 'Your answers to the questions.',
      expected: 'Every blank completed with the word used in your notes.',
      validation: 'Answers come straight from the text you pasted, so a pass means you recalled your notes accurately.',
      concepts: [for (final b in built.take(5)) b.answer],
      theory: theory,
      model: null,
      quiz: quizzes,
      hints: [
        'Re-read the whole sentence: the missing word usually fits its meaning, not just its grammar.',
        'The first answer to look for starts with "${first[0]}" in the first question.',
        'Look for the option that appears elsewhere in the same notes with a related idea.',
      ],
      recovery: recovery,
      reflection: const ['Explain the main idea of your notes in two sentences, without looking.', 'Write one example or application of it.'],
      source: GeneratedSource.notes,
      sourceText: text,
      createdAt: DateTime.now(),
    );
  }

  static String _title(String text) {
    final first = text.split(RegExp(r'[\n]')).first.trim();
    final t = (first.length <= 70 && !first.endsWith('.') ? first : first.split(RegExp(r'\s+')).take(6).join(' ')).replaceFirst(RegExp(r'^(topic|unit|chapter)\s*\d*\s*[:\-]\s*', caseSensitive: false), '');
    return t.isEmpty ? 'your notes' : t;
  }
}
