import 'dart:async';
import 'dart:isolate';

import 'package:dart_eval/dart_eval.dart';

/// One test of a programming challenge. [call] is a Dart expression using the student's `solve` function.
class CodeTestCase {
  final String call;
  final String expectedOutput;
  final String description;
  final bool hidden;

  const CodeTestCase({
    required this.call,
    required this.expectedOutput,
    required this.description,
    this.hidden = false,
  });
}

enum CaseStatus {
  passed,
  wrongAnswer,
  compileError,
  runtimeError,
  timeout,
  runnerFailure,
}

class CaseResult {
  final CaseStatus status;
  final String actual;
  final String message;
  const CaseResult(this.status, {this.actual = '', this.message = ''});

  bool get passed => status == CaseStatus.passed;

  /// The student's code caused this outcome (as opposed to the runner itself failing).
  bool get isStudentFault =>
      status != CaseStatus.passed && status != CaseStatus.runnerFailure;
}

/// Runs student Dart code for real: it is compiled and interpreted by dart_eval in a SEPARATE isolate that has no
/// file, network or process access (dart_eval denies those permissions by default) and is killed after [caseTimeout].
/// Each test case gets its own isolate, so one infinite loop cannot affect the others or the app.
///
/// Limits (be honest with students): Dart only; the interpreter supports a large but not complete subset of Dart;
/// memory is not capped (the isolate shares the app's heap), so this is a classroom sandbox, not a hardened one.
class DartCodeRunner {
  static const String language = 'Dart';
  static const Duration caseTimeout = Duration(seconds: 3);

  static String harness(String studentCode, String call) =>
      '$studentCode\n\nString __campusHarness() {\n  return ($call).toString();\n}\n';

  static Future<CaseResult> runCase(
    String studentCode,
    CodeTestCase test, {
    Duration timeout = caseTimeout,
  }) async {
    final result = ReceivePort();
    final exit = ReceivePort();
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(
        _entry,
        <Object>[result.sendPort, harness(studentCode, test.call)],
        onExit: exit.sendPort,
        errorsAreFatal: true,
      );
      final first = await Future.any<Object?>([
        result.first,
        exit.first.then((_) => 'exited'),
      ]).timeout(timeout);
      if (first is! List) {
        // The isolate ended without answering (crash / out of memory): a runner problem, not necessarily the student's.
        return const CaseResult(
          CaseStatus.runnerFailure,
          message: 'The code runner stopped unexpectedly. Your lives are not affected; try again.',
        );
      }
      final kind = first[0] as String;
      final text = first[1] as String;
      switch (kind) {
        case 'ok':
          final actual = text.trim();
          return actual == test.expectedOutput.trim()
              ? CaseResult(CaseStatus.passed, actual: actual)
              : CaseResult(
                  CaseStatus.wrongAnswer,
                  actual: actual,
                  message:
                      'Expected "${test.expectedOutput}" but got "$actual".',
                );
        case 'compile':
          return CaseResult(CaseStatus.compileError, message: _friendly(text));
        default:
          return CaseResult(CaseStatus.runtimeError, message: text);
      }
    } on TimeoutException {
      return CaseResult(
        CaseStatus.timeout,
        message:
            'Time limit exceeded (${timeout.inSeconds} s). Check for an infinite loop or very slow code.',
      );
    } catch (e) {
      return CaseResult(
        CaseStatus.runnerFailure,
        message:
            'The code runner could not start ($e). Your lives are not affected.',
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      result.close();
      exit.close();
    }
  }

  static String _friendly(String raw) {
    var m = raw.replaceFirst(RegExp(r'^(CompileError:\s*)+'), '').trim();
    if (m.contains('Could not find declaration "solve"')) {
      m = 'Your code must define a function named solve (see the signature in the task). $m';
    }
    return m;
  }
}

// Runs inside the sandbox isolate. Only plain strings cross back.
void _entry(List<Object> args) {
  final port = args[0] as SendPort;
  try {
    final out = eval(args[1] as String, function: '__campusHarness');
    port.send(<String>['ok', '$out']);
  } catch (e) {
    final text = '$e';
    final isCompile =
        e.runtimeType.toString().contains('CompileError') ||
        text.contains('CompileError');
    port.send(<String>[
      isCompile ? 'compile' : 'runtime',
      text.split('\n').first.replaceFirst(RegExp(r'^(Exception:\s*)+'), ''),
    ]);
  }
}
