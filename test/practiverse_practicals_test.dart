import 'package:campus_os/features/practiverse/engine/activity_registry.dart';
import 'package:campus_os/features/practiverse/engine/code_runner.dart';
import 'package:campus_os/features/practiverse/engine/simulation_renderers/code_challenge_simulation.dart';
import 'package:campus_os/features/practiverse/engine/simulation_renderers/ohms_law_simulation.dart';
import 'package:campus_os/features/practiverse/models/practical_activity.dart';
import 'package:campus_os/features/practiverse/models/practical_brief.dart';
import 'package:campus_os/features/practiverse/widgets/code_editor.dart';
import 'package:campus_os/features/practiverse/widgets/line_chart.dart';
import 'package:campus_os/features/practiverse/widgets/practical_brief_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PracticalActivity _act(String id) =>
    ActivityRegistry.allActivities.firstWhere((a) => a.id == id);

LineChartPainter _painter(WidgetTester tester, String chartKey) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byKey(Key(chartKey)),
      matching: find.byType(CustomPaint),
    ),
  );
  return paints.map((p) => p.painter).whereType<LineChartPainter>().single;
}

/// Taps [target] then waits (real time, runners use isolates) until the run finished.
Future<void> _tapAndWait(WidgetTester tester, Finder target) async {
  await tester.runAsync(() async {
    await tester.tap(target);
    for (var i = 0; i < 300; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      if (find.byKey(const Key('code-summary')).evaluate().isNotEmpty &&
          find.textContaining('Compiling and running').evaluate().isEmpty)
        break;
    }
  });
  await tester.pump();
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(padding: const EdgeInsets.all(8), child: child),
  ),
);

void main() {
  group("Ohm's law model", () {
    test('I = V / R, and zero / negative / non-finite resistance is rejected instead of dividing by zero', () {
      expect(OhmsLawModel.current(12, 6), 2);
      expect(OhmsLawModel.current(12, 0), isNull);
      expect(OhmsLawModel.current(12, -3), isNull);
      expect(OhmsLawModel.current(double.nan, 5), isNull);
      expect(OhmsLawModel.current(5, double.infinity), isNull);
    });

    test('graph data is the computed relationship, not decoration', () {
      final vi = OhmsLawModel.voltageCurrent(6);
      expect(vi.first, Offset.zero);
      expect(vi.last, const Offset(30, 5));
      for (final p in vi) {
        expect(p.dy, closeTo(p.dx / 6, 1e-9));
      }
      final ir = OhmsLawModel.currentResistance(12);
      expect(ir.length, 50);
      expect(ir.first, const Offset(1, 12));
      expect(ir.last.dy, closeTo(12 / 50, 1e-9));
      expect(OhmsLawModel.niceCeil(5), 5);
      expect(OhmsLawModel.niceCeil(4.2), 5);
      expect(OhmsLawModel.niceCeil(30), 50 > 30 ? 50 : 30);
    });
  });

  group("Ohm's law practical UI", () {
    Widget sim() => _host(
      OhmsLawSimulation(
        activity: _act('physics_ohms_law'),
        onLifeDeducted: () {},
        onUnlockHint: () {},
        onTriggerRecovery: () {},
        onCompleted: () {},
        currentLives: 3,
      ),
    );

    testWidgets(
      'shows two titled, axis-labelled graphs with real data, and they update when a slider moves',
      (tester) async {
        tester.view.physicalSize = const Size(900, 3200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(sim());

        expect(
          find.textContaining('Graph 1: Current vs Voltage'),
          findsOneWidget,
        );
        expect(find.text('Voltage V (volts)'), findsOneWidget);
        expect(find.text('Current I (amperes)'), findsNWidgets(2));
        expect(
          find.textContaining('Graph 2: Current vs Resistance'),
          findsOneWidget,
        );
        expect(find.text('Resistance R (ohms)'), findsOneWidget);

        var vi = _painter(tester, 'ohm-graph-vi');
        expect(
          vi.series.first.points.last,
          const Offset(30, 5),
        ); // default V=12, R=6 -> slope 1/6
        expect(vi.marker, const Offset(12, 2));

        final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
        sliders[1].onChanged!(12); // resistance 6 -> 12
        await tester.pump();
        vi = _painter(tester, 'ohm-graph-vi');
        expect(
          vi.series.first.points.last,
          const Offset(30, 2.5),
        ); // doubled R halves the current
        expect(vi.marker, const Offset(12, 1));
        expect(find.textContaining('R = 12.0'), findsWidgets);
        sliders[0].onChanged!(24); // voltage 12 -> 24
        await tester.pump();
        expect(_painter(tester, 'ohm-graph-ir').marker, const Offset(12, 2));
      },
    );

    testWidgets(
      'invalid answers are rejected without a crash, a wrong one is not accepted, the formula result appears only after verifying',
      (tester) async {
        tester.view.physicalSize = const Size(900, 3200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var lives = 0, done = 0;
        await tester.pumpWidget(
          _host(
            OhmsLawSimulation(
              activity: _act('physics_ohms_law'),
              onLifeDeducted: () => lives++,
              onUnlockHint: () {},
              onTriggerRecovery: () {},
              onCompleted: () => done++,
              currentLives: 3,
            ),
          ),
        );
        expect(find.textContaining('shown after you verify'), findsOneWidget);
        for (final bad in ['abc', '-2', 'Infinity', '']) {
          await tester.enterText(
            find.byKey(const Key('practiverse-prediction-input')),
            bad,
          );
          await tester.tap(find.byKey(const Key('practiverse-check')));
          await tester.pump();
        }
        expect([lives, done], [0, 0]); // invalid input is not an attempt
        await tester.enterText(
          find.byKey(const Key('practiverse-prediction-input')),
          '36',
        );
        await tester.tap(find.byKey(const Key('practiverse-check')));
        await tester.pump();
        expect([lives, done], [1, 0]);
        await tester.enterText(
          find.byKey(const Key('practiverse-prediction-input')),
          '2',
        );
        await tester.tap(find.byKey(const Key('practiverse-check')));
        await tester.pump();
        expect(done, 1);
        expect(find.textContaining('= 2.000 A'), findsOneWidget);
      },
    );
  });

  group('every practical explains itself', () {
    test('each activity has objective, task, 3+ steps, inputs, expected result and validation', () {
      for (final a in ActivityRegistry.allActivities) {
        final b = PracticalBriefs.of(a);
        expect(b.objective.length, greaterThan(20), reason: a.id);
        expect(b.task.length, greaterThan(20), reason: a.id);
        expect(b.steps.length, greaterThanOrEqualTo(3), reason: a.id);
        expect(
          b.expected.isNotEmpty &&
              b.validation.isNotEmpty &&
              b.inputs.isNotEmpty &&
              b.notice.isNotEmpty,
          isTrue,
          reason: a.id,
        );
      }
    });

    testWidgets('the brief card renders the consistent sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PracticalBriefCard(
            brief: PracticalBriefs.of(_act('physics_ohms_law')),
          ),
        ),
      );
      for (final t in [
        'OBJECTIVE',
        'YOUR TASK',
        'STEPS',
        'WHAT YOU CAN CHANGE',
        'EXPECTED RESULT',
        'HOW IT IS CHECKED',
      ]) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('1.'), findsOneWidget);
      expect(find.textContaining('Software model'), findsOneWidget);
    });

    test('coding practicals state that code is really executed; simulations say they are models', () {
      expect(
        PracticalBriefs.of(_act('cs_sum_two_numbers')).notice,
        contains('Real code execution'),
      );
      expect(
        PracticalBriefs.of(_act('physics_ohms_law')).notice,
        contains('not a real physical experiment'),
      );
    });
  });

  group('Dart code runner (real compile + isolated run)', () {
    const add = CodeTestCase(
      call: 'solve(2, 3)',
      expectedOutput: '5',
      description: 'add',
    );

    test('correct code passes', () async {
      final r = await DartCodeRunner.runCase(
        'int solve(int a, int b) { return a + b; }',
        add,
      );
      expect(r.status, CaseStatus.passed);
      expect(r.actual, '5');
    });

    test(
      'wrong code fails with the real output (no keyword matching)',
      () async {
        final r = await DartCodeRunner.runCase(
          'int solve(int a, int b) { return a - b; }',
          add,
        );
        expect([r.status, r.actual], [CaseStatus.wrongAnswer, '-1']);
        // The old fake checker passed any text containing "a + b": that no longer works.
        final cheat = await DartCodeRunner.runCase(
          '// a + b\nint solve(int a, int b) { return 0; }',
          add,
        );
        expect(cheat.status, CaseStatus.wrongAnswer);
      },
    );

    test('syntax errors and a missing solve() are reported as compile errors with a message', () async {
      final syntax = await DartCodeRunner.runCase(
        'int solve(int a, int b) { return a + ; }',
        add,
      );
      expect(syntax.status, CaseStatus.compileError);
      expect(syntax.message, isNotEmpty);
      final missing = await DartCodeRunner.runCase(
        'int other() { return 1; }',
        add,
      );
      expect(missing.status, CaseStatus.compileError);
      expect(missing.message, contains('solve'));
    });

    test(
      'runtime errors in the student code are reported, not crashed through',
      () async {
        final r = await DartCodeRunner.runCase(
          'int solve(int a, int b) { List<int> l = []; return l[5]; }',
          add,
        );
        expect(r.status, CaseStatus.runtimeError);
        expect(r.isStudentFault, isTrue);
      },
    );

    test(
      'an infinite loop is stopped by the time limit and the app keeps working',
      () async {
        final sw = Stopwatch()..start();
        final r = await DartCodeRunner.runCase(
          'int solve(int a, int b) { while (true) {} return 0; }',
          add,
          timeout: const Duration(seconds: 1),
        );
        expect(r.status, CaseStatus.timeout);
        expect(sw.elapsed, lessThan(const Duration(seconds: 6)));
        final after = await DartCodeRunner.runCase(
          'int solve(int a, int b) { return a + b; }',
          add,
        );
        expect(after.status, CaseStatus.passed);
      },
    );

    test('the sandbox denies file access', () async {
      final r = await DartCodeRunner.runCase(
        "import 'dart:io';\nint solve(int a, int b) { return File('/etc/passwd').readAsStringSync().length; }",
        add,
      );
      expect(r.passed, isFalse);
      expect(
        '${r.status} ${r.message}'.toLowerCase(),
        anyOf(contains('denied'), contains('permission'), contains('error')),
      );
    });

    test('every shipped challenge has a reference solution that passes all of its own tests (visible + hidden)', () async {
      const ref = {
        'cs_sum_two_numbers': 'int solve(int a, int b) { return a + b; }',
        'cs_even_or_odd':
            "String solve(int n) { return n % 2 == 0 ? 'Even' : 'Odd'; }",
        'cs_reverse_string': "String solve(String s) { var out = ''; for (var i = s.length - 1; i >= 0; i--) { out += s[i]; } return out; }",
      };
      for (final e in ref.entries) {
        final spec = CodeChallenges.of(e.key)!;
        expect(spec.tests.any((t) => t.hidden), isTrue, reason: e.key);
        for (final t in spec.tests) {
          final r = await DartCodeRunner.runCase(e.value, t);
          expect(
            r.status,
            CaseStatus.passed,
            reason: '${e.key} ${t.call}: ${r.message} got "${r.actual}"',
          );
        }
        // and the untouched starter code must NOT pass
        final fails = <bool>[];
        for (final t in spec.tests) {
          fails.add((await DartCodeRunner.runCase(spec.starterCode, t)).passed);
        }
        expect(
          fails.every((p) => p),
          isFalse,
          reason: '${e.key} starter code should not pass',
        );
      }
    });
  });

  group('editor deterrents', () {
    TextEditingValue v(String t, {int? start, int? end}) => TextEditingValue(
      text: t,
      selection: TextSelection(
        baseOffset: start ?? t.length,
        extentOffset: end ?? t.length,
      ),
    );

    test('typing, auto-indent and short tokens are allowed; pasting a long snippet is blocked', () {
      var blocked = 0;
      final f = NoPasteFormatter(onBlocked: () => blocked++);
      expect(
        f.formatEditUpdate(v('int solve('), v('int solve(a')).text,
        'int solve(a',
      );
      expect(
        f.formatEditUpdate(v('{'), v('{\n      ')).text,
        '{\n      ',
      ); // newline + indentation
      expect(f.formatEditUpdate(v('ret'), v('return')).text, 'return');
      final pasted = f.formatEditUpdate(v('x'), v('x return a + b + c + d;'));
      expect(pasted.text, 'x');
      expect(blocked, 1);
      // replacing a selection with one character is fine, replacing it with a long paste is not
      expect(
        f.formatEditUpdate(v('hello world', start: 0, end: 11), v('a')).text,
        'a',
      );
      expect(
        f
            .formatEditUpdate(
              v('hello world', start: 0, end: 11),
              v('return a + b + c + d;'),
            )
            .text,
        'hello world',
      );
    });

    test('syntax highlighting colours keywords, types, strings, numbers and comments', () {
      final c = DartHighlightController(
        text: "int f() { return 'x' + 42; } // note",
      );
      final span = c.buildTextSpan(
        context: _FakeContext(),
        withComposing: false,
      );
      final coloured = <String, Color?>{};
      for (final s in span.children!.whereType<TextSpan>()) {
        coloured[s.text!] = s.style?.color;
      }
      expect(coloured['int'], const Color(0xFF0369A1));
      expect(coloured['return'], const Color(0xFF5A6AE8));
      expect(coloured["'x'"], const Color(0xFF15803D));
      expect(coloured['42'], const Color(0xFFB45309));
      expect(coloured['// note'], const Color(0xFF6B7280));
    });
  });

  group('programming challenge workflow (UI)', () {
    Future<void> pump(
      WidgetTester tester, {
      required void Function() onLife,
      required void Function() onDone,
      bool blockPaste = false,
    }) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          CodeChallengeSimulation(
            activity: _act('cs_sum_two_numbers'),
            onLifeDeducted: onLife,
            onUnlockHint: () {},
            onTriggerRecovery: () {},
            onCompleted: onDone,
            currentLives: 3,
            blockPaste: blockPaste,
          ),
        ),
      );
    }

    testWidgets('lists only the supported language and explains why', (
      tester,
    ) async {
      await pump(tester, onLife: () {}, onDone: () {});
      expect(find.byKey(const Key('code-language')), findsOneWidget);
      expect(
        find.textContaining('Only languages with a configured sandbox'),
        findsOneWidget,
      );
      expect(find.textContaining('Paste is disabled'), findsOneWidget);
      expect(find.text('Problem'), findsOneWidget);
    });

    testWidgets(
      'run is free; a failing submit costs a life and shows real results; a correct submit completes',
      (tester) async {
        var lives = 0, done = 0;
        await pump(tester, onLife: () => lives++, onDone: () => done++);

        await tester.enterText(
          find.byKey(const Key('practiverse-solution-input')),
          'int solve(int a, int b) { return a - b; }',
        );
        await _tapAndWait(tester, find.byKey(const Key('code-run')));
        expect(
          find.textContaining('Results: 1 / 3 tests passed'),
          findsOneWidget,
        );
        expect(find.textContaining('got:      -1'), findsWidgets);
        expect(lives, 0); // running is practice

        await _tapAndWait(tester, find.byKey(const Key('practiverse-check')));
        expect([lives, done], [1, 0]);
        expect(find.textContaining('Hidden test'), findsWidgets);

        await tester.enterText(
          find.byKey(const Key('practiverse-solution-input')),
          'int solve(int a, int b) { return a + b; }',
        );
        await _tapAndWait(tester, find.byKey(const Key('practiverse-check')));
        expect(done, 1);
        expect(find.byKey(const Key('code-summary')), findsOneWidget);
        expect(find.textContaining('All tests passed'), findsWidgets);
        expect(find.textContaining('Attempt history'), findsOneWidget);
      },
    );

    testWidgets(
      'a compile error is explained and still counts as a failed submit',
      (tester) async {
        var lives = 0;
        await pump(tester, onLife: () => lives++, onDone: () {});
        await tester.enterText(
          find.byKey(const Key('practiverse-solution-input')),
          'int solve(int a, int b) { return a + ; }',
        );
        await _tapAndWait(tester, find.byKey(const Key('practiverse-check')));
        expect(find.textContaining('Compile error'), findsWidgets);
        expect(lives, 1);
      },
    );

    testWidgets(
      'with paste protection on, a pasted solution is rejected and the student is told why',
      (tester) async {
        await pump(tester, onLife: () {}, onDone: () {}, blockPaste: true);
        await tester.enterText(
          find.byKey(const Key('practiverse-solution-input')),
          '',
        ); // deleting is always allowed
        await tester.enterText(
          find.byKey(const Key('practiverse-solution-input')),
          'int solve(int a, int b) { return a + b; }',
        );
        await tester.pump();
        expect(find.byKey(const Key('code-banner')), findsOneWidget);
        expect(find.textContaining('Pasting code is disabled'), findsOneWidget);
      },
    );
  });
}

class _FakeContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
