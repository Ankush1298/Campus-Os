import 'package:campus_os/features/practiverse/engine/activity_registry.dart';
import 'package:campus_os/features/practiverse/engine/simulation_renderers/dilution_simulation.dart';
import 'package:campus_os/features/practiverse/engine/simulation_renderers/ohms_law_simulation.dart';
import 'package:campus_os/features/practiverse/engine/simulation_renderers/statistics_simulation.dart';
import 'package:campus_os/features/practiverse/engine/topic_intake_engine.dart';
import 'package:campus_os/features/practiverse/models/activity_evaluation.dart';
import 'package:campus_os/features/practiverse/models/practical_activity.dart';
import 'package:campus_os/features/practiverse/models/practical_subject.dart';
import 'package:campus_os/features/practiverse/models/student_progress.dart';
import 'package:campus_os/features/practiverse/screens/topic_intake_screen.dart';
import 'package:campus_os/features/practiverse/screens/virtual_labs_directory_screen.dart';
import 'package:campus_os/features/practiverse/widgets/recovery_question_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PractiVerse Multi-Subject Engine Tests', () {
    test(
      '1. TopicIntakeEngine correctly maps physics keywords and activities',
      () {
        final result = TopicIntakeEngine.analyzeText(
          'DC circuits, Ohm law, resistors, voltage drop, and electrical current measurements',
        );

        expect(result.matchedSubject.category, equals(SubjectCategory.physics));
        expect(
          result.extractedKeyConcepts.any(
            (c) => c.toLowerCase().contains('ohm'),
          ),
          isTrue,
        );
        expect(result.recommendedActivities, isNotEmpty);
        expect(
          result.recommendedActivities.any((a) => a.id == 'physics_ohms_law'),
          isTrue,
        );
      },
    );

    test('2. TopicIntakeEngine correctly maps chemistry dilution concepts', () {
      final result = TopicIntakeEngine.analyzeText(
        'Molarity calculations, aqueous solution dilution C1V1 = C2V2, solute concentration',
      );

      expect(result.matchedSubject.category, equals(SubjectCategory.chemistry));
      expect(
        result.extractedKeyConcepts.any(
          (c) => c.toLowerCase().contains('dilution'),
        ),
        isTrue,
      );
      expect(
        result.recommendedActivities.any((a) => a.id == 'chemistry_dilution'),
        isTrue,
      );
    });

    test(
      '3. TopicIntakeEngine correctly maps mathematics/statistics topics',
      () {
        final result = TopicIntakeEngine.analyzeText(
          'Descriptive statistics, calculating mean median mode and analyzing outlier skewness',
        );

        expect(
          result.matchedSubject.category,
          equals(SubjectCategory.mathematics),
        );
        expect(
          result.extractedKeyConcepts.any(
            (c) =>
                c.toLowerCase().contains('median') ||
                c.toLowerCase().contains('outlier'),
          ),
          isTrue,
        );
        expect(
          result.recommendedActivities.any(
            (a) => a.id == 'math_statistics_data',
          ),
          isTrue,
        );
      },
    );

    test('4. TopicIntakeEngine provides fallback recommendations for empty or general syllabus', () {
      final emptyResult = TopicIntakeEngine.analyzeText('');
      expect(emptyResult.recommendedActivities, isNotEmpty);
      expect(
        emptyResult.matchedSubject.category,
        equals(SubjectCategory.physics),
      );

      final genericResult = TopicIntakeEngine.analyzeText(
        'general engineering laboratory session',
      );
      expect(genericResult.recommendedActivities, isNotEmpty);
    });

    test(
      '5. ActivityRegistry returns activities with valid pedagogical fields',
      () {
        final activities = ActivityRegistry.allActivities;
        expect(activities.length, greaterThanOrEqualTo(5));

        for (final activity in activities) {
          expect(activity.id, isNotEmpty);
          expect(activity.title, isNotEmpty);
          expect(activity.objective, isNotEmpty);
          expect(activity.hints, isNotEmpty);
          expect(activity.recoveryQuestions, isNotEmpty);
          expect(
            activity.recoveryQuestions.first.options.length,
            greaterThanOrEqualTo(3),
          );
          expect(
            activity.recoveryQuestions.first.correctIndex,
            lessThan(activity.recoveryQuestions.first.options.length),
          );
        }
      },
    );

    test('6. ActivityEvaluation tolerance checker handles exact, close, and wrong answers', () {
      // Ohm's law: expected = 1.20 A (12V / 10 Ohm)
      final exactEval = ActivityEvaluationResult.evaluateNumeric(
        prediction: 1.20,
        expected: 1.20,
        tolerancePercent: 0.05,
        unit: 'A',
      );
      expect(exactEval.isCorrect, isTrue);

      // Within 5% tolerance (e.g. 1.24 is 3.3% off)
      final closeEval = ActivityEvaluationResult.evaluateNumeric(
        prediction: 1.24,
        expected: 1.20,
        tolerancePercent: 0.05,
        unit: 'A',
      );
      expect(closeEval.isCorrect, isTrue);

      // Outside tolerance (e.g. 2.0 A)
      final wrongEval = ActivityEvaluationResult.evaluateNumeric(
        prediction: 2.00,
        expected: 1.20,
        tolerancePercent: 0.05,
        unit: 'A',
        commonMisconceptions: {'off_target': 'Check the formula I = V / R'},
      );
      expect(wrongEval.isCorrect, isFalse);
      expect(wrongEval.misconceptionKey, equals('off_target'));
    });

    test('7. StudentProgress lives deduction, restoration, and activity completion', () {
      final progress = StudentProgress();
      expect(progress.lives, equals(3));
      expect(progress.isGameOver, isFalse);

      // Deduct life
      progress.deductLife();
      expect(progress.lives, equals(2));

      progress.deductLife();
      expect(progress.lives, equals(1));

      progress.deductLife();
      expect(progress.lives, equals(0));
      expect(progress.isGameOver, isTrue);

      // Cannot drop below 0
      progress.deductLife();
      expect(progress.lives, equals(0));

      // Restore life via recovery
      progress.restoreLife();
      expect(progress.lives, equals(1));
      expect(progress.isGameOver, isFalse);

      // Complete activity
      progress.markCompleted('physics_ohms_law');
      expect(
        progress.completedActivityIds.contains('physics_ohms_law'),
        isTrue,
      );
      expect(progress.completedActivityIds.length, equals(1));
    });
  });

  group('PractiVerse Simulation Widgets & UI Flow Tests', () {
    testWidgets(
      '8. TopicIntakeScreen renders presets, syllabus input, and allows topic matching',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: TopicIntakeScreen(progress: StudentProgress())),
        );

        expect(find.text('Syllabus Mapping'), findsOneWidget);
        expect(
          find.text('Sample Syllabus Presets (1-Tap Load):'),
          findsOneWidget,
        );
        expect(find.text('Physics (Circuits)'), findsOneWidget);
        expect(
          find.byKey(const Key('practiverse-analyze-btn')),
          findsOneWidget,
        );

        // Tap on Physics preset (first preset, guaranteed within viewport)
        await tester.tap(find.text('Physics (Circuits)'));
        await tester.pumpAndSettle();

        // Should show recommended practicals with physics activity
        expect(
          find.text('Recommended Interactive Practicals:'),
          findsOneWidget,
        );
        expect(find.text("Ohm's Law & DC Circuits"), findsOneWidget);
      },
    );

    testWidgets(
      '9. OhmsLawSimulation renders circuit controls, calculates current, and verifies answer',
      (tester) async {
        final activity = ActivityRegistry.getById('physics_ohms_law')!;
        bool completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OhmsLawSimulation(
                  activity: activity,
                  currentLives: 3,
                  onLifeDeducted: () {},
                  onUnlockHint: () {},
                  onTriggerRecovery: () {},
                  onCompleted: () => completed = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Theoretical Prediction Challenge'), findsOneWidget);
        expect(find.byKey(const Key('practiverse-check')), findsOneWidget);

        // Default: 12V / 6 Ohm = 2.00 A
        final textField = find.byKey(const Key('practiverse-prediction-input'));
        expect(textField, findsOneWidget);
        await tester.enterText(textField, '2.00');
        await tester.pumpAndSettle();

        // Tap verify
        await tester.tap(find.byKey(const Key('practiverse-check')));
        await tester.pumpAndSettle();

        // Shows correct outcome banner and triggers completion
        expect(find.textContaining('Accurate prediction!'), findsOneWidget);
        expect(completed, isTrue);
      },
    );

    testWidgets(
      '10. StatisticsSimulation calculates live mean & median and reacts to outlier injection',
      (tester) async {
        final activity = ActivityRegistry.getById('math_statistics_data')!;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatisticsSimulation(
                  activity: activity,
                  currentLives: 3,
                  onLifeDeducted: () {},
                  onUnlockHint: () {},
                  onTriggerRecovery: () {},
                  onCompleted: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('Arithmetic Mean'), findsOneWidget);
        expect(find.text('Positional Median'), findsOneWidget);
        expect(
          find.byKey(const Key('practiverse-outlier-btn')),
          findsOneWidget,
        );

        // Tap Inject Outlier button
        await tester.tap(find.byKey(const Key('practiverse-outlier-btn')));
        await tester.pumpAndSettle();

        // 150 is now present in the dataset chips
        expect(find.text('150'), findsOneWidget);
      },
    );

    testWidgets(
      '11. DilutionSimulation renders graduated cylinder and computes target concentration',
      (tester) async {
        final activity = ActivityRegistry.getById('chemistry_dilution')!;
        bool completed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DilutionSimulation(
                  activity: activity,
                  currentLives: 3,
                  onLifeDeducted: () {},
                  onUnlockHint: () {},
                  onTriggerRecovery: () {},
                  onCompleted: () => completed = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Dilution Molarity Prediction'), findsOneWidget);
        expect(find.byKey(const Key('practiverse-check')), findsOneWidget);

        // Default: V1 = 50 mL, C1 = 2.0 M, added water = 50 mL => V2 = 100 mL => C2 = (50 * 2) / 100 = 1.00 M
        final textField = find.byKey(const Key('practiverse-prediction-input'));
        await tester.enterText(textField, '1.00');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('practiverse-check')));
        await tester.pumpAndSettle();

        expect(find.textContaining('Accurate prediction!'), findsOneWidget);
        expect(completed, isTrue);
      },
    );

    testWidgets(
      '12. RecoveryQuestionDialog restores life on correct concept answer',
      (tester) async {
        const question = RecoveryQuestion(
          question: 'What is the relationship between current and resistance at constant voltage?',
          options: [
            'Current is inversely proportional to resistance',
            'Current is directly proportional to resistance',
            'Current does not depend on resistance',
          ],
          correctIndex: 0,
          explanation: 'According to Ohm\'s Law I = V/R, current decreases as resistance increases.',
          misconceptionTarget: 'inverse_proportionality',
        );

        bool recovered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => RecoveryQuestionDialog(
                      question: question,
                      onLifeRecovered: () {
                        recovered = true;
                      },
                      onResetLives: () {},
                    ),
                  );
                },
                child: const Text('Open Recovery'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Recovery'));
        await tester.pumpAndSettle();

        expect(find.text('Zero Lives Remaining'), findsOneWidget);
        expect(
          find.text('Current is inversely proportional to resistance'),
          findsOneWidget,
        );

        // Select correct option
        await tester.tap(
          find.text('Current is inversely proportional to resistance'),
        );
        await tester.pumpAndSettle();

        // Tap submit
        await tester.tap(
          find.byKey(const Key('practiverse-recovery-submit-btn')),
        );
        await tester.pumpAndSettle();

        // Dialog shows "Life Restored (+1)!" and the continue button
        expect(find.text('Life Restored (+1)!'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('practiverse-recovery-continue-btn')),
        );
        await tester.pumpAndSettle();

        expect(recovered, isTrue);
      },
    );

    testWidgets(
      '13. VirtualLabsDirectoryScreen lists official external laboratory resources',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: VirtualLabsDirectoryScreen()),
        );

        expect(find.text('Virtual Labs & External Resources'), findsOneWidget);
        expect(
          find.text('Amrita Virtual Labs / Ministry of Education, GoI'),
          findsWidgets,
        );
        expect(
          find.text(
            'PhET Interactive Simulations, University of Colorado Boulder',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
