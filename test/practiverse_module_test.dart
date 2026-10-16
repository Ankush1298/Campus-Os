import 'package:campus_os/features/practiverse/practiverse_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    try {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      return;
    } catch (_) {}
  }

  final scrollable = find.byType(Scrollable).first;
  try {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: scrollable,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
  } catch (_) {
    await tester.scrollUntilVisible(
      finder,
      -250,
      scrollable: scrollable,
      maxScrolls: 30,
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _openSumChallenge(WidgetTester tester) async {
  final challenge = find.text('Sum Two Numbers');
  await _scrollTo(tester, challenge);
  await tester.tap(challenge);
  await tester.pumpAndSettle();
}

Future<void> _tapCheck(WidgetTester tester) async {
  final check = find.byKey(const Key('practiverse-check'));
  await _scrollTo(tester, check);
  await tester.tap(check);
  await tester.pumpAndSettle();
}

void main() {
  group('PractiVerse Module Comprehensive Suite', () {
    // 1. PractiVerse entry point renders successfully
    testWidgets('1. PractiverseModule.getEntryPoint renders successfully', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => PractiverseModule.getEntryPoint(context),
          ),
        ),
      );

      expect(find.text('PractiVerse'), findsOneWidget);
      expect(
        find.text('Build skills.\nSolve real challenges.'),
        findsOneWidget,
      );
      expect(find.text('3 labs'), findsOneWidget);
    });

    // 2. Catalogue contains the expected challenges and quiz entry point
    testWidgets(
      '2. catalogue contains expected challenges and quiz entry point',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PractiverseHomeScreen()),
        );

        expect(find.text('PractiVerse'), findsOneWidget);
        await _scrollTo(tester, find.text('Sum Two Numbers'));
        expect(find.text('Sum Two Numbers'), findsOneWidget);
        await _scrollTo(tester, find.text('Even or Odd'));
        expect(find.text('Even or Odd'), findsOneWidget);
        await _scrollTo(tester, find.text('Reverse a String'));
        expect(find.text('Reverse a String'), findsOneWidget);
        await _scrollTo(tester, find.text('Start verification quiz'));
        expect(find.text('Start verification quiz'), findsOneWidget);
      },
    );

    // 3. A challenge card opens the correct challenge screen
    testWidgets(
      '3. challenge card opens correct challenge screen with details',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PractiverseHomeScreen()),
        );

        final evenOddFinder = find.text('Even or Odd');
        await _scrollTo(tester, evenOddFinder);
        await tester.tap(evenOddFinder);
        await tester.pumpAndSettle();

        expect(find.text('Challenge workspace'), findsOneWidget);
        expect(find.text('Even or Odd'), findsOneWidget);
        expect(find.text('BEGINNER'), findsOneWidget);
        expect(
          find.textContaining('Return EVEN when a number is divisible by 2'),
          findsOneWidget,
        );
        expect(find.text('14'), findsOneWidget);
        expect(find.text('EVEN'), findsWidgets);
      },
    );

    // 4. Empty answers are rejected without losing a life
    testWidgets('4. empty answer is rejected without consuming a life', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PractiverseHomeScreen()));
      await _openSumChallenge(tester);
      expect(find.text('3 lives'), findsOneWidget);

      await _tapCheck(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-feedback')));
      expect(find.text('Enter an answer before checking.'), findsOneWidget);
      expect(find.text('3 lives'), findsOneWidget);
    });

    // 5. Incorrect answers consume exactly one life
    testWidgets('5. wrong answer consumes exactly one life', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PractiverseHomeScreen()));
      await _openSumChallenge(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-answer')));
      await tester.enterText(
        find.byKey(const Key('practiverse-answer')),
        'wrong',
      );
      await _tapCheck(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-feedback')));

      expect(find.text('2 lives'), findsOneWidget);
      expect(find.textContaining('Some tests failed'), findsOneWidget);
    });

    // 6. Repeated interactions do not double-deduct a single attempt
    testWidgets('6. repeated interactions do not double-deduct attempt', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PractiverseHomeScreen()));
      await _openSumChallenge(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-answer')));
      await tester.enterText(
        find.byKey(const Key('practiverse-answer')),
        'wrong',
      );
      await _tapCheck(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-feedback')));

      expect(find.text('2 lives'), findsOneWidget);

      // Check button is disabled until explicit retry
      final check = find.byKey(const Key('practiverse-check'));
      await _scrollTo(tester, check);
      expect(tester.widget<FilledButton>(check).onPressed, isNull);
      expect(find.text('2 lives'), findsOneWidget);
    });

    // 7. Correct answers show success and update completion state
    testWidgets('7. correct answer updates completion state in catalogue', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PractiverseHomeScreen()));
      await _openSumChallenge(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-answer')));
      await tester.enterText(find.byKey(const Key('practiverse-answer')), '11');
      await _tapCheck(tester);
      await _scrollTo(tester, find.byKey(const Key('practiverse-feedback')));

      expect(find.text('Challenge passed'), findsOneWidget);
      expect(find.text('Test cases passed: 3 / 3'), findsOneWidget);
      expect(
        find.textContaining('no arbitrary code was executed'),
        findsOneWidget,
      );

      // Return to catalogue and check completion
      final returnBtn = find.byKey(const Key('practiverse-return-catalogue'));
      await _scrollTo(tester, returnBtn);
      await tester.tap(returnBtn);
      await tester.pumpAndSettle();

      final summaryFinder = find.text('1 of 3 challenges completed');
      await _scrollTo(tester, summaryFinder);
      expect(summaryFinder, findsOneWidget);
      await _scrollTo(tester, find.text('COMPLETED'));
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    // 8. Hints reveal incrementally without consuming lives
    testWidgets('8. hints reveal incrementally without spending lives', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PractiverseHomeScreen()));
      await _openSumChallenge(tester);
      final hintButton = find.text('Reveal hint (0/2)');
      await _scrollTo(tester, hintButton);
      await tester.tap(hintButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hint 1:'), findsOneWidget);
      expect(find.text('3 lives'), findsOneWidget);
      expect(find.text('Reveal hint (1/2)'), findsOneWidget);

      await tester.tap(find.text('Reveal hint (1/2)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hint 2:'), findsOneWidget);
      expect(find.text('All hints revealed'), findsOneWidget);
      expect(find.text('3 lives'), findsOneWidget);
    });

    // 9. Quiz options can be selected and selections are reflected in the UI
    testWidgets('9. quiz options can be selected and reflect selection state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: PractiverseQuizScreen(onCompleted: (_) {})),
      );

      final optionFinder = find.text('+');
      await _scrollTo(tester, optionFinder);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      final radioGroup = tester.widget<RadioGroup<int>>(
        find.byType(RadioGroup<int>).first,
      );
      expect(radioGroup.groupValue, 0);
    });

    // 10. An unanswered quiz cannot be submitted successfully
    testWidgets('10. an unanswered quiz cannot be submitted successfully', (
      tester,
    ) async {
      var submitted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PractiverseQuizScreen(onCompleted: (_) => submitted = true),
        ),
      );

      final submitBtn = find.byKey(const Key('practiverse-submit-quiz'));
      await _scrollTo(tester, submitBtn);
      expect(tester.widget<FilledButton>(submitBtn).onPressed, isNull);
      expect(submitted, isFalse);
    });

    // 11. Quiz score is calculated from the chosen answers
    testWidgets('11. quiz score is calculated from chosen answers', (
      tester,
    ) async {
      int? reportedScore;
      await tester.pumpWidget(
        MaterialApp(
          home: PractiverseQuizScreen(
            onCompleted: (score) => reportedScore = score,
          ),
        ),
      );

      // Select 5 answers: 4 correct, 1 wrong
      // Q1: '+' (correct)
      // Q2: 'When remainder after division by 2 is zero' (correct)
      // Q3: 'Places characters in reverse order' (correct)
      // Q4: 'Reject it without consuming a life' (correct)
      // Q5: 'A compiler service' (wrong, correct is deterministic)
      const selectedAnswers = [
        '+',
        'When remainder after division by 2 is zero',
        'Places characters in reverse order',
        'Reject it without consuming a life',
        'A compiler service',
      ];

      for (final option in selectedAnswers) {
        final optionFinder = find.text(option);
        await _scrollTo(tester, optionFinder);
        await tester.tap(optionFinder);
        await tester.pumpAndSettle();
      }

      final submit = find.byKey(const Key('practiverse-submit-quiz'));
      await _scrollTo(tester, submit);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(reportedScore, 4);
      final scoreFinder = find.text('You scored 4 out of 5.');
      await _scrollTo(tester, scoreFinder);
      expect(scoreFinder, findsOneWidget);
    });

    // 12. Quiz submission cannot score twice
    testWidgets('12. quiz submission cannot score twice', (tester) async {
      var completionCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PractiverseQuizScreen(onCompleted: (_) => completionCalls++),
        ),
      );

      final firstOptions = [
        '+',
        'When remainder after division by 2 is zero',
        'Places characters in reverse order',
        'Reject it without consuming a life',
        'Deterministic expected-answer simulation',
      ];
      for (final opt in firstOptions) {
        final optFinder = find.text(opt);
        await _scrollTo(tester, optFinder);
        await tester.tap(optFinder);
        await tester.pumpAndSettle();
      }

      final submit = find.byKey(const Key('practiverse-submit-quiz'));
      await _scrollTo(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(completionCalls, 1);
      // Submit button is gone
      expect(find.byKey(const Key('practiverse-submit-quiz')), findsNothing);
    });

    // 13. Users can navigate back to the catalogue from challenge and quiz screens
    testWidgets(
      '13. users can navigate back to catalogue from challenge and quiz',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PractiverseHomeScreen()),
        );

        // Open challenge and navigate back
        await _openSumChallenge(tester);
        expect(find.text('Challenge workspace'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('PractiVerse'), findsOneWidget);

        // Open quiz and navigate back
        final quizBtn = find.text('Start verification quiz');
        await _scrollTo(tester, quizBtn);
        await tester.tap(quizBtn);
        await tester.pumpAndSettle();
        expect(find.text('Verification quiz'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('PractiVerse'), findsOneWidget);
      },
    );

    // 14. Important controls remain operable on a small test viewport
    testWidgets(
      '14. important controls remain operable on a small test viewport',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: PractiverseHomeScreen()),
        );
        expect(find.text('PractiVerse'), findsOneWidget);

        final challenge = find.text('Reverse a String');
        await _scrollTo(tester, challenge);
        await tester.tap(challenge);
        await tester.pumpAndSettle();

        expect(find.text('Reverse a String'), findsOneWidget);
        final answerField = find.byKey(const Key('practiverse-answer'));
        await _scrollTo(tester, answerField);
        await tester.enterText(answerField, 'supmac');

        final checkBtn = find.byKey(const Key('practiverse-check'));
        await _scrollTo(tester, checkBtn);
        await tester.tap(checkBtn);
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.byKey(const Key('practiverse-feedback')));
        expect(find.text('Challenge passed'), findsOneWidget);
        expect(find.text('Test cases passed: 3 / 3'), findsOneWidget);

        final returnBtn = find.byKey(const Key('practiverse-return-catalogue'));
        await _scrollTo(tester, returnBtn);
        await tester.tap(returnBtn);
        await tester.pumpAndSettle();

        final summaryFinder = find.text('1 of 3 challenges completed');
        await _scrollTo(tester, summaryFinder);
        expect(summaryFinder, findsOneWidget);
      },
    );

    // 15. Recovery question unlocks on zero lives and restores life upon correct answer
    testWidgets(
      '15. recovery question unlocks on zero lives and restores life',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PractiverseHomeScreen()),
        );
        await _openSumChallenge(tester);

        // Fail 3 times to consume all 3 lives
        for (var i = 0; i < 3; i++) {
          final answerField = find.byKey(const Key('practiverse-answer'));
          await _scrollTo(tester, answerField);
          await tester.enterText(answerField, 'bad-$i');
          await _tapCheck(tester);
          if (i < 2) {
            final retryBtn = find.text('Retry with remaining lives');
            await _scrollTo(tester, retryBtn);
            await tester.tap(retryBtn);
            await tester.pumpAndSettle();
          }
        }

        expect(find.text('0 lives'), findsOneWidget);
        final recoveryTitle = find.text('Life Recovery Question');
        await _scrollTo(tester, recoveryTitle);
        expect(recoveryTitle, findsOneWidget);

        // Select correct answer 'n'
        final option = find.text('n');
        await _scrollTo(tester, option);
        await tester.tap(option);
        await tester.pumpAndSettle();

        // Submit recovery
        final submitRecovery = find.byKey(
          const Key('practiverse-recovery-submit'),
        );
        await _scrollTo(tester, submitRecovery);
        await tester.tap(submitRecovery);
        await tester.pumpAndSettle();

        // Verify life restored to 1
        expect(find.text('1 lives'), findsOneWidget);
        expect(
          find.textContaining('Recovery successful! +1 life granted'),
          findsOneWidget,
        );
      },
    );

    // 16. Timed verification quiz counts down and auto-submits on expiration
    testWidgets(
      '16. timed verification quiz counts down and auto-submits on expiration',
      (tester) async {
        var completed = false;
        var scoreResult = -1;

        await tester.pumpWidget(
          MaterialApp(
            home: PractiverseQuizScreen(
              timeLimitSeconds: 2,
              onCompleted: (score) {
                completed = true;
                scoreResult = score;
              },
            ),
          ),
        );

        expect(find.text('Time left: 0:02'), findsOneWidget);

        // Advance 1 second
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Time left: 0:01'), findsOneWidget);
        expect(completed, isFalse);

        // Advance final second to expire timer
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(completed, isTrue);
        expect(scoreResult, 0); // No answers chosen = 0
        expect(find.text('Quiz complete'), findsOneWidget);
      },
    );
  });
}
