import 'package:flutter/material.dart';

import '../../models/practical_activity.dart';
import '../../models/activity_evaluation.dart';

class StatisticsSimulation extends StatefulWidget {
  final PracticalActivity activity;
  final VoidCallback onLifeDeducted;
  final VoidCallback onUnlockHint;
  final VoidCallback onTriggerRecovery;
  final VoidCallback onCompleted;
  final int currentLives;

  const StatisticsSimulation({
    super.key,
    required this.activity,
    required this.onLifeDeducted,
    required this.onUnlockHint,
    required this.onTriggerRecovery,
    required this.onCompleted,
    required this.currentLives,
  });

  @override
  State<StatisticsSimulation> createState() => _StatisticsSimulationState();
}

class _StatisticsSimulationState extends State<StatisticsSimulation> {
  final List<double> _dataset = [12, 14, 15, 18, 21];
  final TextEditingController _addNumberController = TextEditingController();
  final TextEditingController _predictionController = TextEditingController();
  ActivityEvaluationResult? _lastEvaluation;
  bool _evaluated = false;

  double get _mean {
    if (_dataset.isEmpty) return 0;
    final sum = _dataset.fold<double>(0, (prev, val) => prev + val);
    return sum / _dataset.length;
  }

  double get _median {
    if (_dataset.isEmpty) return 0;
    final sorted = List<double>.from(_dataset)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2.0;
    }
  }

  void _addNumber() {
    final val = double.tryParse(_addNumberController.text.trim());
    if (val != null) {
      setState(() {
        _dataset.add(val);
        _addNumberController.clear();
        _evaluated = false;
      });
    }
  }

  void _injectOutlier() {
    setState(() {
      _dataset.add(150.0);
      _evaluated = false;
    });
  }

  void _resetDataset() {
    setState(() {
      _dataset.clear();
      _dataset.addAll([12, 14, 15, 18, 21]);
      _evaluated = false;
      _lastEvaluation = null;
      _predictionController.clear();
    });
  }

  void _evaluateMedianPrediction() {
    final text = _predictionController.text.trim();
    final double? predicted = double.tryParse(text);

    if (predicted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric value.')),
      );
      return;
    }

    final double expected = _median;
    final eval = ActivityEvaluationResult.evaluateNumeric(
      prediction: predicted,
      expected: expected,
      tolerancePercent: 0.02,
      unit: '',
      formulaName: 'Positional Median of Sorted Dataset',
    );

    setState(() {
      _lastEvaluation = eval;
      _evaluated = true;
    });

    if (eval.isCorrect) {
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
    _addNumberController.dispose();
    _predictionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<double>.from(_dataset)..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Virtual Model Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE9D5FF)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.query_stats_rounded,
                color: Color(0xFF5A6AE8),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Virtual Mathematical Model: Mean vs. Median Sensitivity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B21A8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Metric Counters
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Arithmetic Mean',
                value: _mean.toStringAsFixed(2),
                subtitle: 'Sum / Count',
                color: const Color(0xFF0E7C86),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Positional Median',
                value: _median.toStringAsFixed(2),
                subtitle: 'Middle Rank',
                color: const Color(0xFF5A6AE8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Dataset Elements Chips
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Dataset (N = ${_dataset.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _resetDataset,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(_dataset.length, (i) {
                    final isExtreme = _dataset[i] >= 100;
                    return Chip(
                      label: Text(
                        _dataset[i].toStringAsFixed(0),
                        style: TextStyle(
                          color: isExtreme
                              ? Colors.white
                              : const Color(0xFF0B1B3A),
                          fontWeight: isExtreme
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: isExtreme
                          ? const Color(0xFFEF4444)
                          : const Color(0xFFF1F5F9),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () {
                        setState(() {
                          _dataset.removeAt(i);
                          _evaluated = false;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sorted sequence: [${sorted.map((e) => e.toStringAsFixed(0)).join(', ')}]',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF56667F),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addNumberController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter number to add',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addNumber,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Add'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const Key('practiverse-outlier-btn'),
                      onPressed: _injectOutlier,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('+ Outlier (150)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Prediction Challenge
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Median Calculation Challenge',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Inspect the active sorted dataset. Calculate the exact positional median:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF46566F)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('practiverse-prediction-input'),
                        controller: _predictionController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 15.0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      key: const Key('practiverse-check'),
                      onPressed: _evaluateMedianPrediction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A6AE8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Verify'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Outcome Display
        if (_evaluated && _lastEvaluation != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lastEvaluation!.isCorrect
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _lastEvaluation!.isCorrect
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
                      _lastEvaluation!.isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: _lastEvaluation!.isCorrect
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastEvaluation!.feedback,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _lastEvaluation!.isCorrect
                              ? const Color(0xFF166534)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final step in _lastEvaluation!.stepByStepDerivation)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '• $step',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2C3C58),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF56667F)),
          ),
        ],
      ),
    );
  }
}
