import 'package:flutter/material.dart';

import '../../models/practical_activity.dart';

class CodeTestCase {
  final String input;
  final String expectedOutput;
  final String description;

  const CodeTestCase({
    required this.input,
    required this.expectedOutput,
    required this.description,
  });
}

class CodeChallengeSimulation extends StatefulWidget {
  final PracticalActivity activity;
  final VoidCallback onLifeDeducted;
  final VoidCallback onUnlockHint;
  final VoidCallback onTriggerRecovery;
  final VoidCallback onCompleted;
  final int currentLives;

  const CodeChallengeSimulation({
    super.key,
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
  final TextEditingController _solutionController = TextEditingController();
  List<bool?> _testResults = [];
  bool _executed = false;
  bool _allPassed = false;

  List<CodeTestCase> get _testCases {
    switch (widget.activity.id) {
      case 'cs_sum_two_numbers':
        return const [
          CodeTestCase(
            input: 'a = 2, b = 3',
            expectedOutput: '5',
            description: 'Small positive integers',
          ),
          CodeTestCase(
            input: 'a = -4, b = 10',
            expectedOutput: '6',
            description: 'Negative and positive integers',
          ),
          CodeTestCase(
            input: 'a = 0, b = 0',
            expectedOutput: '0',
            description: 'Zero identity case',
          ),
        ];
      case 'cs_even_or_odd':
        return const [
          CodeTestCase(
            input: 'number = 4',
            expectedOutput: 'Even',
            description: 'Standard positive even number',
          ),
          CodeTestCase(
            input: 'number = 7',
            expectedOutput: 'Odd',
            description: 'Standard positive odd number',
          ),
          CodeTestCase(
            input: 'number = 0',
            expectedOutput: 'Even',
            description: 'Zero is even',
          ),
        ];
      case 'cs_reverse_string':
        return const [
          CodeTestCase(
            input: "text = 'campus'",
            expectedOutput: "'supmac'",
            description: 'Standard lowercase word',
          ),
          CodeTestCase(
            input: "text = 'radar'",
            expectedOutput: "'radar'",
            description: 'Palindrome word',
          ),
          CodeTestCase(
            input: "text = 'A'",
            expectedOutput: "'A'",
            description: 'Single character boundary',
          ),
        ];
      default:
        return const [
          CodeTestCase(
            input: 'test = 1',
            expectedOutput: '1',
            description: 'Generic test',
          ),
        ];
    }
  }

  void _runChecks() {
    final code = _solutionController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your solution implementation.'),
        ),
      );
      return;
    }

    final lower = code.toLowerCase();
    List<bool> results = [];

    switch (widget.activity.id) {
      case 'cs_sum_two_numbers':
        final bool valid =
            (lower.contains('a + b') ||
                lower.contains('return a+b') ||
                lower.contains('return a + b')) &&
            !lower.contains('fail');
        results = [valid, valid, valid];
        break;
      case 'cs_even_or_odd':
        final bool valid =
            (lower.contains('% 2') || lower.contains('%2')) &&
            (lower.contains('even') && lower.contains('odd'));
        results = [valid, valid, valid];
        break;
      case 'cs_reverse_string':
        final bool valid =
            (lower.contains('reversed') ||
                lower.contains('split') ||
                lower.contains('for') ||
                lower.contains('while')) &&
            !lower.contains('fail');
        results = [valid, valid, valid];
        break;
      default:
        results = [true];
    }

    final bool allGood = results.every((r) => r);

    setState(() {
      _testResults = results;
      _executed = true;
      _allPassed = allGood;
    });

    if (allGood) {
      widget.onCompleted();
    } else {
      widget.onLifeDeducted();
      widget.onUnlockHint();
      if (widget.currentLives <= 1) {
        widget.onTriggerRecovery();
      }
    }
  }

  @override
  void dispose() {
    _solutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tests = _testCases;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Problem Description
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Problem Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.activity.objective,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Examples:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                for (final tc in tests.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      '• Input: ${tc.input} ➔ Output: ${tc.expectedOutput}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Solution Editor
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Write Your Solution',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('practiverse-solution-input'),
                  controller: _solutionController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText:
                        '// Enter code or logic here\n// e.g. return a + b;',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('practiverse-check'),
                    onPressed: _runChecks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Run checks'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Test Cases Outcome
        if (_executed) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _allPassed
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _allPassed
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _allPassed
                            ? 'All Test Cases Passed!'
                            : 'Some Test Cases Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _allPassed
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  for (int i = 0; i < tests.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            (_testResults.length > i && _testResults[i] == true)
                                ? Icons.check_circle_outline_rounded
                                : Icons.highlight_off_rounded,
                            size: 16,
                            color:
                                (_testResults.length > i &&
                                    _testResults[i] == true)
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Test ${i + 1}: ${tests[i].description} (${tests[i].input})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
