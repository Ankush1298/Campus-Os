import 'package:flutter/material.dart';

import '../models/practical_activity.dart';

class RecoveryQuestionDialog extends StatefulWidget {
  final RecoveryQuestion question;
  final VoidCallback onLifeRecovered;
  final VoidCallback onResetLives;

  const RecoveryQuestionDialog({
    super.key,
    required this.question,
    required this.onLifeRecovered,
    required this.onResetLives,
  });

  @override
  State<RecoveryQuestionDialog> createState() => _RecoveryQuestionDialogState();
}

class _RecoveryQuestionDialogState extends State<RecoveryQuestionDialog> {
  int? _selectedOption;
  bool _submitted = false;
  bool _wasCorrect = false;

  void _submitAnswer() {
    if (_selectedOption == null) return;
    setState(() {
      _submitted = true;
      _wasCorrect = _selectedOption == widget.question.correctIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.heart_broken_rounded,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero Lives Remaining',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          'Answer this concept check to earn +1 Life back!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF56667F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.question.question,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B1B3A),
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: _selectedOption,
                onChanged: _submitted
                    ? (val) {}
                    : (val) {
                        setState(() {
                          _selectedOption = val;
                        });
                      },
                child: Column(
                  children: List.generate(widget.question.options.length, (
                    index,
                  ) {
                    final optText = widget.question.options[index];
                    Color? tileColor;
                    if (_submitted) {
                      if (index == widget.question.correctIndex) {
                        tileColor = const Color(0xFFDCFCE7);
                      } else if (index == _selectedOption) {
                        tileColor = const Color(0xFFFEE2E2);
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: tileColor ?? Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedOption == index
                                  ? const Color(0xFF0E7C86)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: RadioListTile<int>(
                            value: index,
                            dense: true,
                            title: Text(
                              optText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1B2B4B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (_submitted) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _wasCorrect
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _wasCorrect
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _wasCorrect
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: _wasCorrect
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _wasCorrect
                                ? 'Life Restored (+1)!'
                                : 'Incorrect Recovery Answer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _wasCorrect
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.question.explanation,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2C3C58),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const Key('practiverse-reset-lives-btn'),
                    onPressed: () {
                      widget.onResetLives();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Reset Session (3 Lives)',
                      style: TextStyle(color: Color(0xFF56667F)),
                    ),
                  ),
                  if (!_submitted)
                    ElevatedButton(
                      key: const Key('practiverse-recovery-submit-btn'),
                      onPressed: _selectedOption == null ? null : _submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E7C86),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Submit & Recover'),
                    )
                  else
                    ElevatedButton(
                      key: const Key('practiverse-recovery-continue-btn'),
                      onPressed: () {
                        if (_wasCorrect) {
                          widget.onLifeRecovered();
                        }
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _wasCorrect
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF46566F),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _wasCorrect ? 'Resume Simulation (+1 Life)' : 'Close',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
