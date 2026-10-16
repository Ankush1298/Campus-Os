import 'package:flutter/material.dart';

import '../../models/practical_activity.dart';
import '../../widgets/code_editor.dart';
import '../code_runner.dart';

/// Problem statement + tests for one programming challenge.
class CodeChallengeSpec {
  final String statement;
  final String inputFormat;
  final String outputFormat;
  final String constraints;
  final List<String> examples;
  final String starterCode;
  final List<CodeTestCase> tests; // visible and hidden

  const CodeChallengeSpec({
    required this.statement,
    required this.inputFormat,
    required this.outputFormat,
    required this.constraints,
    required this.examples,
    required this.starterCode,
    required this.tests,
  });

  List<CodeTestCase> get visible => tests.where((t) => !t.hidden).toList();
}

class CodeChallenges {
  static CodeChallengeSpec? of(String activityId) => _specs[activityId];

  static const Map<String, CodeChallengeSpec> _specs = {
    'cs_sum_two_numbers': CodeChallengeSpec(
      statement: 'Write a function solve that takes two integers and returns their sum.',
      inputFormat:
          'Two integers a and b, passed as the arguments of solve(a, b).',
      outputFormat: 'The integer a + b.',
      constraints: '-1,000,000 ≤ a, b ≤ 1,000,000.',
      examples: ['solve(2, 3)  ->  5', 'solve(-4, 10)  ->  6'],
      starterCode: 'int solve(int a, int b) {\n  // write your code here\n  return 0;\n}\n',
      tests: [
        CodeTestCase(
          call: 'solve(2, 3)',
          expectedOutput: '5',
          description: 'Small positive integers',
        ),
        CodeTestCase(
          call: 'solve(-4, 10)',
          expectedOutput: '6',
          description: 'Negative and positive',
        ),
        CodeTestCase(
          call: 'solve(0, 0)',
          expectedOutput: '0',
          description: 'Zero identity',
        ),
        CodeTestCase(
          call: 'solve(1000000, 1000000)',
          expectedOutput: '2000000',
          description: 'Upper bound',
          hidden: true,
        ),
        CodeTestCase(
          call: 'solve(-1000000, -1)',
          expectedOutput: '-1000001',
          description: 'Both negative',
          hidden: true,
        ),
        CodeTestCase(
          call: 'solve(7, -7)',
          expectedOutput: '0',
          description: 'Cancels out',
          hidden: true,
        ),
      ],
    ),
    'cs_even_or_odd': CodeChallengeSpec(
      statement: "Write a function solve that takes an integer n and returns the text 'Even' if n is even, or 'Odd' if it is odd.",
      inputFormat: 'One integer n, passed as solve(n).',
      outputFormat:
          "The exact text Even or Odd (capital first letter, nothing else).",
      constraints: '-1,000,000 ≤ n ≤ 1,000,000. Zero is even; negative numbers can be odd too.',
      examples: ["solve(4)  ->  Even", "solve(7)  ->  Odd"],
      starterCode:
          "String solve(int n) {\n  // write your code here\n  return '';\n}\n",
      tests: [
        CodeTestCase(
          call: 'solve(4)',
          expectedOutput: 'Even',
          description: 'Positive even',
        ),
        CodeTestCase(
          call: 'solve(7)',
          expectedOutput: 'Odd',
          description: 'Positive odd',
        ),
        CodeTestCase(
          call: 'solve(0)',
          expectedOutput: 'Even',
          description: 'Zero is even',
        ),
        CodeTestCase(
          call: 'solve(-3)',
          expectedOutput: 'Odd',
          description: 'Negative odd',
          hidden: true,
        ),
        CodeTestCase(
          call: 'solve(-8)',
          expectedOutput: 'Even',
          description: 'Negative even',
          hidden: true,
        ),
        CodeTestCase(
          call: 'solve(999999)',
          expectedOutput: 'Odd',
          description: 'Large odd',
          hidden: true,
        ),
      ],
    ),
    'cs_reverse_string': CodeChallengeSpec(
      statement: 'Write a function solve that takes a string s and returns s with its characters in reverse order.',
      inputFormat: "One string s, passed as solve(s).",
      outputFormat: 'The reversed string.',
      constraints: '0 ≤ length of s ≤ 1000. The empty string reverses to the empty string.',
      examples: ["solve('campus')  ->  supmac", "solve('radar')  ->  radar"],
      starterCode: "String solve(String s) {\n  // write your code here\n  return '';\n}\n",
      tests: [
        CodeTestCase(
          call: "solve('campus')",
          expectedOutput: 'supmac',
          description: 'Ordinary word',
        ),
        CodeTestCase(
          call: "solve('radar')",
          expectedOutput: 'radar',
          description: 'Palindrome',
        ),
        CodeTestCase(
          call: "solve('A')",
          expectedOutput: 'A',
          description: 'Single character',
        ),
        CodeTestCase(
          call: "solve('')",
          expectedOutput: '',
          description: 'Empty string',
          hidden: true,
        ),
        CodeTestCase(
          call: "solve('ab cd')",
          expectedOutput: 'dc ba',
          description: 'Contains a space',
          hidden: true,
        ),
        CodeTestCase(
          call: "solve('12345')",
          expectedOutput: '54321',
          description: 'Digits',
          hidden: true,
        ),
      ],
    ),
  };
}

/// One Run/Submit in the attempt history.
class CodeAttempt {
  final DateTime at;
  final bool submitted;
  final int passed;
  final int total;
  final String note;
  const CodeAttempt({
    required this.at,
    required this.submitted,
    required this.passed,
    required this.total,
    required this.note,
  });
}

class CodeChallengeSimulation extends StatefulWidget {
  final PracticalActivity activity;
  final VoidCallback onLifeDeducted;
  final VoidCallback onUnlockHint;
  final VoidCallback onTriggerRecovery;
  final VoidCallback onCompleted;
  final int currentLives;
  final bool blockPaste; // only tests turn this off

  const CodeChallengeSimulation({
    super.key,
    this.blockPaste = true,
    required this.activity,
    required this.onLifeDeducted,
    required this.onUnlockHint,
    required this.onTriggerRecovery,
    required this.onCompleted,
    required this.currentLives,
  });

  @override
  State<CodeChallengeSimulation> createState() =>
      _CodeChallengeSimulationState();
}

class _CodeChallengeSimulationState extends State<CodeChallengeSimulation> {
  late final DartHighlightController _code;
  CodeChallengeSpec? get _spec => CodeChallenges.of(widget.activity.id);

  String _language = DartCodeRunner.language;
  bool _busy = false;
  bool _passedAll = false;
  List<(CodeTestCase, CaseResult)> _results = [];
  final List<CodeAttempt> _history = [];
  String? _banner; // runner / paste notices

  @override
  void initState() {
    super.initState();
    _code = DartHighlightController(text: _spec?.starterCode ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _execute({required bool submit}) async {
    final spec = _spec;
    if (spec == null || _busy) return;
    final source = _code.text;
    if (source.trim().isEmpty) {
      setState(() => _banner = 'Write some code first.');
      return;
    }
    final tests = submit ? spec.tests : spec.visible;
    setState(() {
      _busy = true;
      _banner = null;
      _results = [];
    });

    final results = <(CodeTestCase, CaseResult)>[];
    for (final t in tests) {
      final r = await DartCodeRunner.runCase(source, t);
      results.add((t, r));
      // A compile error or runner failure repeats identically for every test: stop early.
      if (r.status == CaseStatus.compileError ||
          r.status == CaseStatus.runnerFailure)
        break;
    }
    if (!mounted) return;

    final passed = results.where((e) => e.$2.passed).length;
    final allPassed = results.length == tests.length && passed == tests.length;
    final runnerFailed = results.any(
      (e) => e.$2.status == CaseStatus.runnerFailure,
    );
    final compileError = results.any(
      (e) => e.$2.status == CaseStatus.compileError,
    );

    setState(() {
      _busy = false;
      _results = results;
      _passedAll = submit && allPassed;
      _history.insert(
        0,
        CodeAttempt(
          at: DateTime.now(),
          submitted: submit,
          passed: passed,
          total: tests.length,
          note: runnerFailed
              ? 'Runner problem (not counted)'
              : compileError
              ? 'Compile error'
              : allPassed
              ? 'All tests passed'
              : '${tests.length - passed} failing',
        ),
      );
      if (runnerFailed) _banner = 'The code runner had a problem. Nothing was counted against you; try again.';
    });

    if (!submit || runnerFailed)
      return; // Run is free practice; a runner outage never costs a life
    if (allPassed) {
      widget.onCompleted();
    } else {
      widget.onLifeDeducted();
      widget.onUnlockHint();
      if (widget.currentLives <= 1) widget.onTriggerRecovery();
    }
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            k,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF46566F),
            ),
          ),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontSize: 12.5, height: 1.35)),
        ),
      ],
    ),
  );

  Widget _resultRow((CodeTestCase, CaseResult) e) {
    final t = e.$1, r = e.$2;
    final ok = r.passed;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.hidden
                      ? 'Hidden test: ${t.description}'
                      : '${t.description}   ${t.call}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!t.hidden)
                  Text(
                    'expected: ${t.expectedOutput.isEmpty ? '(empty)' : t.expectedOutput}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                if (!ok && r.status == CaseStatus.wrongAnswer && !t.hidden)
                  Text(
                    'got:      ${r.actual.isEmpty ? '(empty)' : r.actual}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                if (!ok && r.status != CaseStatus.wrongAnswer)
                  Text(
                    _statusLabel(r),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                if (!ok && t.hidden)
                  const Text(
                    'Your output differs on this hidden input.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(CaseResult r) {
    switch (r.status) {
      case CaseStatus.compileError:
        return 'Compile error: ${r.message}';
      case CaseStatus.runtimeError:
        return 'Runtime error: ${r.message}';
      case CaseStatus.timeout:
        return r.message;
      case CaseStatus.runnerFailure:
        return r.message;
      default:
        return r.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    if (spec == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('This challenge has no test cases configured yet.'),
        ),
      );
    }
    final passedCount = _results.where((e) => e.$2.passed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Problem',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  spec.statement,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                _kv('Input', spec.inputFormat),
                _kv('Output', spec.outputFormat),
                _kv('Constraints', spec.constraints),
                _kv('Examples', spec.examples.join('\n')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Language: ',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            DropdownButton<String>(
              key: const Key('code-language'),
              value: _language,
              items: const [
                DropdownMenuItem(value: 'Dart', child: Text('Dart')),
              ],
              onChanged: (v) => setState(() => _language = v ?? _language),
            ),
          ],
        ),
        const Text(
          'Only languages with a configured sandbox are listed. Python, Java or C++ need a server-side runner that is not set up in this build.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF56667F)),
        ),
        const SizedBox(height: 8),
        CodeEditor(
          controller: _code,
          blockPaste: widget.blockPaste,
          onPasteBlocked: () => setState(
            () => _banner = 'Pasting code is disabled during practicals. Type your solution yourself.',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Paste is disabled here because typing helps you learn. This is a classroom deterrent only; it cannot stop screenshots or other apps.',
          style: TextStyle(fontSize: 11, color: Color(0xFF56667F)),
        ),
        if (_banner != null) ...[
          const SizedBox(height: 8),
          Container(
            key: const Key('code-banner'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _banner!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('code-run'),
                onPressed: _busy ? null : () => _execute(submit: false),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Run visible tests'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('practiverse-check'),
                onPressed: _busy ? null : () => _execute(submit: true),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E7C86),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Reset to starter code',
              onPressed: _busy
                  ? null
                  : () => setState(() => _code.text = spec.starterCode),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Run is free practice. A failed Submit costs one life; a runner problem never does.',
          style: TextStyle(fontSize: 11, color: Color(0xFF56667F)),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Compiling and running your code...',
                  style: TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _passedAll
                ? 'All tests passed: challenge complete'
                : 'Results: $passedCount / ${_results.length} tests passed',
            key: const Key('code-summary'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _passedAll
                  ? const Color(0xFF166534)
                  : const Color(0xFF2C3C58),
            ),
          ),
          const SizedBox(height: 6),
          for (final e in _results) _resultRow(e),
        ],
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Attempt history',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _history.length; i++)
            Text(
              '#${_history.length - i}  ${_history[i].submitted ? 'Submit' : 'Run'}  ${_history[i].at.hour.toString().padLeft(2, '0')}:${_history[i].at.minute.toString().padLeft(2, '0')}:${_history[i].at.second.toString().padLeft(2, '0')}'
              '   ${_history[i].passed}/${_history[i].total}   ${_history[i].note}',
              style: const TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: Color(0xFF46566F),
              ),
            ),
        ],
      ],
    );
  }
}
