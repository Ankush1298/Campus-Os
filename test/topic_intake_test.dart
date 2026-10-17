import 'package:campus_os/features/practiverse/practiverse_module.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/practiverse/engine/practical_generator.dart';
import 'package:campus_os/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> ids(String text) =>
    TopicIntakeEngine.analyzeText(text).recommendedActivities
        .map((a) => a.id)
        .toSet();

void main() {
  group('whole-word matching (the old substring matcher fired inside unrelated words)', () {
    test('"model", "medicine", "database", "basement" do not trigger statistics / physics / chemistry', () {
      final r = TopicIntakeEngine.analyzeText(
        'We built a model of a modern basement database for the medicine department.',
      );
      expect(r.matched, isFalse);
    });

    test('plurals, case and typographic apostrophes are understood', () {
      expect(ids('OHM’S LAW and RESISTORS'), contains('physics_ohms_law'));
      expect(ids("ohm's law"), contains('physics_ohms_law'));
      expect(
        ids('Voltages across resistances in electric circuits'),
        contains('physics_ohms_law'),
      );
      expect(ids('Outliers and medians'), contains('math_statistics_data'));
      expect(
        ids('Dilutions of solutions, molarities'),
        contains('chemistry_dilution'),
      );
    });

    test('short common words alone are not enough ("even if the mean value is odd")', () {
      expect(
        TopicIntakeEngine.analyzeText(
          'Even if the mean value is odd, we continue.',
        ).matched,
        isFalse,
      );
    });
  });

  group('honest results', () {
    test('unrelated text is reported as no match (not silently "Physics") and lists everything as browsable', () {
      final r = TopicIntakeEngine.analyzeText(
        'The history of the Mughal empire and medieval trade routes',
      );
      expect(r.matched, isFalse);
      expect(r.recommendedActivities.length, ActivityRegistryCount.total);
      expect(
        r.pedagogicalGuidance,
        contains('No PractiVerse practical matches'),
      );
    });

    test('empty input does not claim a match', () {
      final r = TopicIntakeEngine.analyzeText('   ');
      expect(r.matched, isFalse);
      expect(r.topicMappings, isEmpty);
    });

    test('recognised topics without a practical are listed, with the closest foundation practical offered', () {
      final r = TopicIntakeEngine.analyzeText(
        "Kirchhoff's voltage law and loop analysis",
      );
      expect(r.unsupportedTopics.join(' '), contains('Kirchhoff'));
      expect(
        r.recommendedActivities.map((a) => a.id),
        contains('physics_ohms_law'),
      );
      final calc = TopicIntakeEngine.analyzeText(
        'Calculus: derivatives and integrals',
      );
      expect(calc.matched, isFalse);
      expect(calc.unsupportedTopics.join(' '), contains('Calculus'));
    });
  });

  group('syllabus extraction', () {
    const syllabus = '''
Course: Engineering Foundations (EF101)
Unit 2: Core Topics
Topics:
- Ohm's law and experimental verification using ammeters and voltmeters
- Mean, median and the effect of outliers
- Preparing a stock solution by dilution (C1V1 = C2V2)
- Fourier transforms and signal sampling
Learning Objectives: connect theory with measurements.
''';

    test('each bullet is mapped to its own practical; headings are ignored; unmatched lines say "no practical yet"', () {
      final r = TopicIntakeEngine.analyzeText(syllabus);
      final byTopic = {
        for (final m in r.topicMappings) m.topic: m.activity?.id,
      };
      expect(
        byTopic["Ohm's law and experimental verification using ammeters and voltmeters"],
        'physics_ohms_law',
      );
      expect(
        byTopic['Mean, median and the effect of outliers'],
        'math_statistics_data',
      );
      expect(
        byTopic['Preparing a stock solution by dilution (C1V1 = C2V2)'],
        'chemistry_dilution',
      );
      expect(byTopic['Fourier transforms and signal sampling'], isNull);
      expect(
        r.topicMappings.any((m) => m.topic.toLowerCase().startsWith('course')),
        isFalse,
      );
      expect(
        r.recommendedActivities.map((a) => a.id),
        containsAll([
          'physics_ohms_law',
          'math_statistics_data',
          'chemistry_dilution',
        ]),
      );
    });

    test(
      'a multi-subject syllabus reports every subject, ranked, not just one',
      () {
        final r = TopicIntakeEngine.analyzeText(syllabus);
        expect(r.matched, isTrue);
        expect(r.otherSubjects.length, greaterThanOrEqualTo(1));
        final all = {r.matchedSubject.id, ...r.otherSubjects.map((s) => s.id)};
        expect(all, containsAll(['physics', 'mathematics', 'chemistry']));
      },
    );

    test('free text without bullets is split on commas / sentences', () {
      final r = TopicIntakeEngine.analyzeText(
        'Descriptive statistics, standard deviation, median. Acid base titration; molarity of a solute.',
      );
      expect(r.topicMappings.length, greaterThanOrEqualTo(4));
      expect(
        r.topicMappings.where((m) => m.hasPractical).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('numbered lists and "a)" style items are recognised as topics', () {
      final topics = TopicIntakeEngine.extractTopics(
        '1. Parity checks with modulo\n2) Reversing strings and palindromes\na) Sum of two numbers',
      );
      expect(topics.length, 3);
    });

    test(
      'every built-in sample syllabus maps to its own subject practicals',
      () {
        const expected = {
          'Physics (Circuits)': 'physics_ohms_law',
          'Mathematics (Statistics)': 'math_statistics_data',
          'Chemistry (Solutions)': 'chemistry_dilution',
        };
        for (final e in expected.entries) {
          final r = TopicIntakeEngine.analyzeText(
            TopicIntakeEngine.sampleSyllabuses[e.key]!,
          );
          expect(r.matched, isTrue, reason: e.key);
          expect(r.recommendedActivities.first.id, e.value, reason: e.key);
        }
        final cs = TopicIntakeEngine.analyzeText(
          TopicIntakeEngine.sampleSyllabuses['Computer Science (Algorithms)']!,
        );
        expect(
          cs.recommendedActivities.map((a) => a.id),
          containsAll([
            'cs_sum_two_numbers',
            'cs_even_or_odd',
            'cs_reverse_string',
          ]),
        );
      },
    );
  });

  group('computer science', () {
    test('specific coding topics find the specific challenge', () {
      expect(ids('Modulo and parity'), contains('cs_even_or_odd'));
      expect(
        ids('Reverse a string, palindromes'),
        contains('cs_reverse_string'),
      );
      expect(
        ids('Adding two numbers: arithmetic expressions'),
        contains('cs_sum_two_numbers'),
      );
    });

    test('general programming vocabulary offers all coding challenges', () {
      final r = ids(
        'Intro to programming: algorithms, loops and writing code in Dart',
      );
      expect(
        r,
        containsAll([
          'cs_sum_two_numbers',
          'cs_even_or_odd',
          'cs_reverse_string',
        ]),
      );
    });
  });

  group('results screen', () {
    testWidgets(
      'shows topic-by-topic coverage and the no-practical-yet marker',
      (tester) async {
        tester.view.physicalSize = const Size(900, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(home: TopicIntakeScreen(progress: StudentProgress())),
        );
        await tester.enterText(
          find.byKey(const Key('practiverse-syllabus-input')),
          "- Ohm's law\n- Fourier transforms",
        );
        await tester.tap(find.byKey(const Key('practiverse-analyze-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Topics found in your text:'), findsOneWidget);
        expect(
          find.textContaining('no practical yet', findRichText: true),
          findsWidgets,
        );
        expect(
          find.textContaining("Ohm's Law & DC Circuits", findRichText: true),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'unrelated text shows the explicit no-match state, not a fake Physics match',
      (tester) async {
        tester.view.physicalSize = const Size(900, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(home: TopicIntakeScreen(progress: StudentProgress())),
        );
        await tester.enterText(
          find.byKey(const Key('practiverse-syllabus-input')),
          'Medieval trade routes and the Mughal empire',
        );
        await tester.tap(find.byKey(const Key('practiverse-analyze-btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('intake-no-match')), findsOneWidget);
        expect(find.text('All available practicals:'), findsOneWidget);
        expect(find.text('Physics & Electronics'), findsNothing);
      },
    );
  });

  group('generate a practical for ANY topic (the intake screen)', () {
    const notes = '''
Medieval trade routes
The Silk Road connected China with the Mediterranean world through a network of caravan routes.
Merchants carried silk, spices and porcelain westward and brought gold, glass and horses back east.
Caravanserais provided safe lodging for traders and their camels along the desert crossings.
The spread of Buddhism and later Islam followed the same trading corridors across Central Asia.
Maritime routes through the Indian Ocean grew as monsoon winds made sailing predictable.
''';

    setUp(() {
      GeneratedPracticalStore.resetCache();
      AuthService.instance.currentSession.value = UserSession.demoStudent();
    });
    tearDown(() => AuthService.instance.currentSession.value = null);

    testWidgets('notes on a subject the app has no practical for still become a working practical', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: TopicIntakeScreen(progress: StudentProgress())));
      await tester.enterText(find.byKey(const Key('practiverse-syllabus-input')), notes);
      await tester.tap(find.byKey(const Key('practiverse-generate-btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Recall check: Medieval trade routes'), findsWidgets); // the workspace opened
      expect(find.textContaining('Built from your own notes (no AI)'), findsOneWidget); // and it says where it came from
    });

    testWidgets('a bare topic with no AI available says exactly what is needed, and does not invent a practical', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: TopicIntakeScreen(progress: StudentProgress())));
      await tester.enterText(find.byKey(const Key('practiverse-syllabus-input')), 'Medieval trade routes');
      await tester.tap(find.byKey(const Key('practiverse-generate-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gen-message')), findsOneWidget);
      expect(find.textContaining('paste several sentences'), findsOneWidget);
      expect(find.textContaining('Recall check'), findsNothing);
    });

    testWidgets('when no built-in practical matches, generating is offered right there', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: TopicIntakeScreen(progress: StudentProgress())));
      await tester.enterText(find.byKey(const Key('practiverse-syllabus-input')), 'Medieval trade routes and the Mughal empire');
      await tester.tap(find.byKey(const Key('practiverse-analyze-btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('intake-no-match')), findsOneWidget);
      expect(find.byKey(const Key('intake-generate-from-nomatch')), findsOneWidget);
    });
  });
}



class ActivityRegistryCount {
  static int get total => ActivityRegistry.allActivities.length;
}
