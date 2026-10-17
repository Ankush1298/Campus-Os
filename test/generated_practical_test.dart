import 'dart:convert';
import 'dart:io';

import 'package:campus_os/core/network/api_client.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/practiverse/engine/formula.dart';
import 'package:campus_os/features/practiverse/engine/local_practical_builder.dart';
import 'package:campus_os/features/practiverse/engine/practical_generator.dart';
import 'package:campus_os/features/practiverse/engine/simulation_renderers/generated_simulation.dart';
import 'package:campus_os/features/practiverse/models/generated_practical.dart';
import 'package:campus_os/features/practiverse/models/practical_brief.dart';
import 'package:campus_os/features/practiverse/practiverse_module.dart';
import 'package:campus_os/features/practiverse/widgets/line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

const live = UserSession(token: 't', id: '22CS1', name: 'Riya', role: 'student');

const notes = '''
Photosynthesis in plants
Photosynthesis is the process by which green plants convert light energy into chemical energy.
Chlorophyll absorbs sunlight mainly in the blue and red wavelengths of the spectrum.
The light reactions take place in the thylakoid membranes and produce ATP and NADPH.
During the Calvin cycle, carbon dioxide is fixed into glucose inside the stroma.
Stomata are tiny pores on the leaf surface that regulate gas exchange with the atmosphere.
Oxygen is released as a by-product when water molecules are split during photolysis.
''';

const history = '''
Causes of the French Revolution
Heavy taxation burdened the Third Estate while the nobility and clergy enjoyed exemptions from most taxes.
Enlightenment thinkers such as Voltaire and Rousseau challenged absolute monarchy and inherited privilege.
Poor harvests in 1788 raised the price of bread and caused widespread hunger in Paris.
The costly American war left the royal treasury almost bankrupt under Louis XVI.
The storming of the Bastille in July 1789 became the symbol of popular revolt.
''';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(8), child: child)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formula engine (same grammar as the server)', () {
    double? ev(String s, [Map<String, double> env = const {}]) => Formula.parse(s, env.keys.toSet()).evaluate(env);

    test('precedence, associativity, unary minus, functions and constants', () {
      expect(ev('2 + 3 * 4'), 14);
      expect(ev('(2 + 3) * 4'), 20);
      expect(ev('2 ^ 3 ^ 2'), 512);
      expect(ev('-2 ^ 2'), -4);
      expect(ev('V / R', {'V': 12, 'R': 6}), 2);
      expect(ev('sqrt(x^2 + y^2)', {'x': 3, 'y': 4}), closeTo(5, 1e-12));
      expect(ev('P * (1 + r/100)^n', {'P': 1000, 'r': 10, 'n': 2}), closeTo(1210, 1e-9));
      expect(ev('ln(e) + log10(100) + pi - pi'), closeTo(3, 1e-12));
      expect(ev('max(a, b) - min(a, b)', {'a': 7, 'b': 3}), 4);
    });

    test('undefined results are null, never NaN or infinity', () {
      expect(ev('1 / x', {'x': 0}), isNull);
      expect(ev('sqrt(x)', {'x': -1}), isNull);
      expect(ev('ln(x)', {'x': 0}), isNull);
      expect(ev('exp(x)', {'x': 100000}), isNull);
    });

    test('anything outside the grammar is rejected (no code execution possible)', () {
      for (final bad in ["__import__('os')", 'a.b', 'foo(1)', 'x; y', "open('f')", '1 +', '((1)', 'x y', 'lambda: 1', 'x[0]', 'import os', 'a' * 300, r'$x', '']) {
        expect(() => Formula.parse(bad, {'x', 'y', 'a'}), throwsA(isA<FormulaException>()), reason: bad);
      }
      expect(() => Formula.parse('zzz + 1', {'x'}), throwsA(isA<FormulaException>())); // undeclared name
    });
  });

  group('contract with the server', () {
    test('a server-validated practical parses, keeps its formula and re-validates', () {
      final p = GeneratedPractical.fromJson(Map<String, dynamic>.from(fixture('generated_practical_server.json')['practical'] as Map), sourceText: "Ohm's law");
      expect(p.source, GeneratedSource.ai);
      expect(p.model, isNotNull);
      expect(p.model!.answer({'V': 12, 'R': 6}), 2);
      expect(p.quiz.length, 5);
      expect(p.sourceLabel, contains('AI-generated'));
    });

    test('a non-quantitative topic has no formula: it is a scenario simulation, and the quiz is only remediation', () {
      final p = GeneratedPractical.fromJson(Map<String, dynamic>.from(fixture('generated_practical_history.json')['practical'] as Map), sourceText: 'Judicial review');
      expect(p.model, isNull);
      expect(p.scenario!.rounds.length, 3);
      expect(p.practicalKind, 'scenario');
      expect(p.theory!.sections.length, greaterThanOrEqualTo(2));
      final a = p.toActivity();
      expect(a.kind, ActivityKind.generated);
      expect(a.diagnosticQuizQuestions, isEmpty); // no second exam after success
    });

    test('the device re-applies the scenario rule: exactly one best choice per round', () {
      final j = Map<String, dynamic>.from(fixture('generated_practical_history.json')['practical'] as Map);
      ((j['scenario'] as Map)['rounds'] as List)[0]['choices'][1]['score'] = 2; // two best answers
      expect(GeneratedPractical.fromJson(j, sourceText: 'x').scenario, isNull);
    });

    test('the device does not trust a model block that the server would drop (and a damaged practical is rejected)', () {
      final j = Map<String, dynamic>.from(fixture('generated_practical_server.json')['practical'] as Map);
      (j['model'] as Map)['expression'] = 'V / (R - 1)'; // undefined at the minimum R = 1
      expect(GeneratedPractical.fromJson(j, sourceText: 'x').model, isNull);
      final j2 = Map<String, dynamic>.from(fixture('generated_practical_server.json')['practical'] as Map)..['quiz'] = [];
      expect(() => GeneratedPractical.fromJson(j2, sourceText: 'x'), throwsFormatException);
    });

    test('REAL model output (captured live through the server) is accepted by the app, and the app computes its own answer', () {
      final fin = GeneratedPractical.fromJson(Map<String, dynamic>.from(fixture('generated_practical_live_finance.json')['practical'] as Map), sourceText: 'Compound interest');
      expect(fin.model, isNotNull);
      final env = fin.model!.defaults();
      final answer = fin.model!.answer(env)!;
      expect(answer, greaterThan(0));
      expect(fin.model!.questionFor(env), isNot(contains('{'))); // every placeholder was filled
      expect(fin.quiz.length, greaterThanOrEqualTo(3));
      expect(fin.theory, isNotNull);
      final law = GeneratedPractical.fromJson(Map<String, dynamic>.from(fixture('generated_practical_live_law.json')['practical'] as Map), sourceText: 'Judicial review');
      expect(law.toActivity().kind, ActivityKind.generated);
      expect(law.scenario!.rounds.length, greaterThanOrEqualTo(2));
      expect(law.theory!.sections, isNotEmpty);
    });

    test('stored practicals round-trip', () {
      final p = GeneratedPractical.fromJson(Map<String, dynamic>.from(fixture('generated_practical_server.json')['practical'] as Map), sourceText: 'src');
      final back = GeneratedPractical.fromStored(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.title, p.title);
      expect(back.model!.expression, p.model!.expression);
      expect(back.sourceText, 'src');
    });
  });

  group('local builder (no AI, from the pasted notes)', () {
    test('builds answerable questions for any subject from the text alone', () {
      for (final text in [notes, history]) {
        final p = LocalPracticalBuilder.fromNotes(text)!;
        expect(p.source, GeneratedSource.notes);
        expect(p.quiz.length, greaterThanOrEqualTo(3));
        for (final q in [...p.quiz, p.recovery]) {
          expect(q.options.toSet().length, 4);
          expect(q.question, contains('_____'));
          final correct = q.options[q.correctIndex];
          // the answer is a word that really is in the source text, and the explanation quotes the sentence that contains it
          expect(text.toLowerCase(), contains(correct.toLowerCase()));
          expect(q.explanation.toLowerCase(), contains(correct.toLowerCase()));
        }
      }
    });

    test('is honest about what it cannot do', () {
      expect(LocalPracticalBuilder.fromNotes('Photosynthesis'), isNull);
      expect(LocalPracticalBuilder.fromNotes('Ohm\'s law and resistors'), isNull);
      expect(LocalPracticalBuilder.fromNotes('Short note. Another short one.'), isNull);
    });
  });

  group('generator service', () {
    final serverJson = fixture('generated_practical_server.json');

    test('signed-in users get the AI practical from the server', () async {
      final r = await PracticalGenerator.generate("Ohm's law", session: live, remote: (_) async => serverJson);
      expect(r.ok, isTrue);
      expect(r.practical!.source, GeneratedSource.ai);
      expect(r.message, isNull);
    });

    test('an unconfigured server falls back to the notes builder, and says why', () async {
      final r = await PracticalGenerator.generate(notes, session: live, remote: (_) async => throw ApiException(statusCode: 503, message: 'x', details: {'error': {'code': 'llm_not_configured'}}));
      expect(r.practical!.source, GeneratedSource.notes);
      expect(r.message, contains('GROQ_API_KEY'));
    });

    test('a bare topic with no AI available fails with an actionable message (no fake practical)', () async {
      final r = await PracticalGenerator.generate('Photosynthesis', session: live, remote: (_) async => throw ApiException(statusCode: 0, message: 'offline'));
      expect(r.ok, isFalse);
      expect(r.message, contains('paste several sentences'));
      expect(r.message, contains('Cannot reach'));
    });

    test('rate limits and refusals are shown as they are, not hidden by a fallback', () async {
      final limited = await PracticalGenerator.generate(notes, session: live, remote: (_) async => throw ApiException(statusCode: 429, message: 'limit reached'));
      expect([limited.ok, limited.message], [false, 'limit reached']);
      final refused = await PracticalGenerator.generate(notes, session: live, remote: (_) async => throw ApiException(statusCode: 422, message: 'declined', details: {'error': {'code': 'refused'}}));
      expect([refused.ok, refused.message], [false, 'declined']);
    });

    test('a damaged AI answer is never used', () async {
      final bad = {'practical': {'title': 'x', 'steps': [], 'quiz': []}};
      final r = await PracticalGenerator.generate(notes, session: live, remote: (_) async => bad);
      expect(r.practical!.source, GeneratedSource.notes);
      expect(r.message, contains('could not be used'));
    });

    test('demo mode uses the same server path (a restricted demo token is fetched internally), and falls back honestly', () async {
      var called = false;
      final ok = await PracticalGenerator.generate("Ohm's law", session: UserSession.demoStudent(), remote: (_) async {
        called = true;
        return serverJson;
      });
      expect([called, ok.practical!.source], [true, GeneratedSource.ai]);
      final down = await PracticalGenerator.generate(notes, session: UserSession.demoStudent(), remote: (_) async => throw ApiException(statusCode: 0, message: 'offline'));
      expect(down.practical!.source, GeneratedSource.notes);
      expect(down.message, contains('Cannot reach'));
    });

    test('with no session at all there is no AI, and the message says so', () async {
      final r = await PracticalGenerator.generate(notes, session: null);
      expect(r.practical!.source, GeneratedSource.notes);
      expect(r.message, contains('not signed in'));
    });
  });

  group('generated lesson: theory -> practical -> quiz only if failed', () {
    GeneratedPractical gp(String file) => GeneratedPractical.fromJson(Map<String, dynamic>.from(fixture(file)['practical'] as Map), sourceText: 't');
    PracticalActivity act(String file) => gp(file).toActivity();

    Widget sim(PracticalActivity a, {void Function()? onLife, void Function()? onDone}) => host(GeneratedSimulation(
          activity: a,
          onLifeDeducted: onLife ?? () {},
          onUnlockHint: () {},
          onTriggerRecovery: () {},
          onCompleted: onDone ?? () {},
          currentLives: 3,
        ));

    Future<void> big(WidgetTester t) async {
      t.view.physicalSize = const Size(900, 5000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    LineChartPainter painter(WidgetTester t) => t.widgetList<CustomPaint>(find.descendant(of: find.byKey(const Key('gen-graph')), matching: find.byType(CustomPaint))).map((p) => p.painter).whereType<LineChartPainter>().single;

    double sliderValue(WidgetTester t, String name) => t.widget<Slider>(find.byKey(Key('gen-slider-$name'))).value;

    Future<void> answerQuiz(WidgetTester t, GeneratedPractical g, {required bool correct}) async {
      for (var i = 0; i < g.quiz.length; i++) {
        final o = correct ? g.quiz[i].correctIndex : (g.quiz[i].correctIndex + 1) % 4;
        await t.tap(find.byKey(Key('gen-rq$i-o$o')));
        await t.pump();
      }
      await t.tap(find.byKey(const Key('gen-submit-quiz')));
      await t.pump();
    }

    testWidgets('THEORY comes first: the practical is not shown until the theory is read', (t) async {
      await big(t);
      await t.pumpWidget(sim(act('generated_practical_server.json')));
      expect(find.byKey(const Key('gen-theory-overview')), findsOneWidget);
      expect(find.text('Learn first: theory'), findsOneWidget);
      expect(find.byKey(const Key('gen-question')), findsNothing);
      expect(find.byKey(const Key('practiverse-check')), findsNothing);
      expect(find.byKey(const Key('gen-stepper')), findsOneWidget);
      await t.tap(find.byKey(const Key('gen-start-practical')));
      await t.pump();
      expect(find.byKey(const Key('gen-question')), findsOneWidget);
      expect(find.byKey(const Key('gen-theory-overview')), findsNothing);
    });

    testWidgets('FORMULA practical: sliders drive the question and the graph; a wrong answer forces the review quiz; passing it allows a retry with NEW values', (t) async {
      await big(t);
      var done = 0, lives = 0;
      final g = gp('generated_practical_server.json');
      await t.pumpWidget(sim(g.toActivity(), onDone: () => done++, onLife: () => lives++));
      await t.tap(find.byKey(const Key('gen-start-practical')));
      await t.pump();
      expect(find.textContaining('A 6 ohm resistor is across 12 volt'), findsOneWidget);
      expect(painter(t).marker!.dy, 2);
      t.widget<Slider>(find.byKey(const Key('gen-slider-R'))).onChanged!(12);
      await t.pump();
      expect(painter(t).marker!.dy, 1);

      // invalid input is not an attempt
      await t.enterText(find.byKey(const Key('practiverse-prediction-input')), 'abc');
      await t.tap(find.byKey(const Key('practiverse-check')));
      await t.pump();
      expect([done, lives], [0, 0]);

      // WRONG answer: life lost, Verify disappears, the quiz is now required
      await t.enterText(find.byKey(const Key('practiverse-prediction-input')), '5');
      await t.tap(find.byKey(const Key('practiverse-check')));
      await t.pump();
      expect([done, lives], [0, 1]);
      expect(find.byKey(const Key('practiverse-check')), findsNothing);
      expect(find.byKey(const Key('gen-take-quiz')), findsOneWidget);
      final before = (sliderValue(t, 'V'), sliderValue(t, 'R'));

      await t.tap(find.byKey(const Key('gen-take-quiz')));
      await t.pump();
      expect(find.text('Review quiz'), findsOneWidget);
      await answerQuiz(t, g, correct: false); // failing the quiz does not unlock the retry
      expect(find.text('Re-read the theory'), findsOneWidget);
      expect(find.text('Retry the practical'), findsNothing);
      await t.tap(find.byKey(const Key('gen-after-quiz'))); // -> theory
      await t.pump();
      expect(find.byKey(const Key('gen-theory-overview')), findsOneWidget);
      await t.tap(find.byKey(const Key('gen-start-practical'))); // "Back to the quiz"
      await t.pump();
      await answerQuiz(t, g, correct: true);
      expect(find.text('Retry the practical'), findsOneWidget);
      await t.tap(find.byKey(const Key('gen-after-quiz')));
      await t.pump();

      // retry: fresh values, graded against the formula
      final v = sliderValue(t, 'V'), r = sliderValue(t, 'R');
      expect((v, r) == before, isFalse);
      await t.enterText(find.byKey(const Key('practiverse-prediction-input')), (v / r * 1.02).toStringAsFixed(4)); // within 5%
      await t.tap(find.byKey(const Key('practiverse-check')));
      await t.pump();
      expect(done, 1);
      expect(find.byKey(const Key('gen-passed')), findsOneWidget);
    });

    testWidgets('SCENARIO practical: decisions are scored per round; a poor result forces the quiz; a good retry passes', (t) async {
      await big(t);
      var done = 0, lives = 0;
      final g = gp('generated_practical_history.json');
      final sc = g.scenario!;
      await t.pumpWidget(sim(g.toActivity(), onDone: () => done++, onLife: () => lives++));
      expect(find.byKey(const Key('gen-scenario-setup')), findsNothing); // theory first
      await t.tap(find.byKey(const Key('gen-start-practical')));
      await t.pump();
      expect(find.byKey(const Key('gen-scenario-setup')), findsOneWidget);

      Future<void> playRound(int round, int score) async {
        final idx = sc.rounds[round].choices.indexWhere((c) => c.score == score);
        await t.ensureVisible(find.byKey(Key('gen-choice-$round-$idx')));
        await t.tap(find.byKey(Key('gen-choice-$round-$idx')));
        await t.pump();
        expect(find.byKey(const Key('gen-choice-feedback')), findsOneWidget); // consequence is explained at once
        await t.ensureVisible(find.byKey(const Key('gen-next-round')));
        await t.tap(find.byKey(const Key('gen-next-round')));
        await t.pump();
      }

      for (var r = 0; r < sc.rounds.length; r++) {
        await playRound(r, 0); // all worst decisions
      }
      expect([done, lives], [0, 1]);
      expect(find.byKey(const Key('gen-take-quiz')), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('gen-take-quiz')));
      await t.tap(find.byKey(const Key('gen-take-quiz')));
      await t.pump();
      await answerQuiz(t, g, correct: true);
      await t.tap(find.byKey(const Key('gen-after-quiz')));
      await t.pump();
      expect(find.byKey(const Key('gen-situation')), findsOneWidget); // scenario restarted at round 1
      for (var r = 0; r < sc.rounds.length; r++) {
        await playRound(r, 2); // all best decisions
      }
      expect(done, 1);
      expect(find.byKey(const Key('gen-passed')), findsOneWidget);
    });

    testWidgets('RECALL lesson built from notes: theory = your notes; failing means re-read and retry (no separate quiz)', (t) async {
      await big(t);
      var done = 0, lives = 0;
      final g = LocalPracticalBuilder.fromNotes(notes)!;
      await t.pumpWidget(sim(g.toActivity(), onDone: () => done++, onLife: () => lives++));
      expect(find.textContaining('your own notes'), findsWidgets);
      await t.tap(find.byKey(const Key('gen-start-practical')));
      await t.pump();
      final inline = (g.quiz.length + 1) ~/ 2;
      for (var i = 0; i < inline; i++) {
        await t.tap(find.byKey(Key('gen-q$i-o${(g.quiz[i].correctIndex + 1) % 4}')));
        await t.pump();
      }
      await t.ensureVisible(find.byKey(const Key('practiverse-check')));
      await t.tap(find.byKey(const Key('practiverse-check')));
      await t.pump();
      expect([done, lives], [0, 1]);
      await t.ensureVisible(find.byKey(const Key('gen-take-quiz')));
      await t.tap(find.byKey(const Key('gen-take-quiz'))); // "Re-read the theory, then retry"
      await t.pump();
      expect(find.byKey(const Key('gen-theory-overview')), findsOneWidget);
      await t.tap(find.byKey(const Key('gen-start-practical'))); // "Retry the practical"
      await t.pump();
      for (var i = 0; i < inline; i++) {
        await t.tap(find.byKey(Key('gen-q$i-o${g.quiz[i].correctIndex}')));
        await t.pump();
      }
      await t.ensureVisible(find.byKey(const Key('practiverse-check')));
      await t.tap(find.byKey(const Key('practiverse-check')));
      await t.pump();
      expect(done, 1);
    });

    testWidgets('the workspace explains the flow and shows the source; finishing shows no extra exam', (t) async {
      t.view.physicalSize = const Size(900, 6000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final a = act('generated_practical_server.json');
      await t.pumpWidget(MaterialApp(home: ActivityWorkspaceScreen(activity: a, progress: StudentProgress())));
      await t.pump();
      expect(find.textContaining('Lesson flow: 1) read the theory'), findsOneWidget);
      expect(find.textContaining('AI-generated from your topic'), findsOneWidget);
      expect(find.byKey(const Key('practiverse-start-quiz')), findsNothing);
      expect(PracticalBriefs.of(a).steps, isNotEmpty);
    });
  });
}
