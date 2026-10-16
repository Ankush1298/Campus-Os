import 'package:flutter/material.dart';

import '../../models/practical_activity.dart';
import '../../models/activity_evaluation.dart';
import '../../widgets/beaker_painter.dart';

class DilutionSimulation extends StatefulWidget {
  final PracticalActivity activity;
  final VoidCallback onLifeDeducted;
  final VoidCallback onUnlockHint;
  final VoidCallback onTriggerRecovery;
  final VoidCallback onCompleted;
  final int currentLives;

  const DilutionSimulation({
    super.key,
    required this.activity,
    required this.onLifeDeducted,
    required this.onUnlockHint,
    required this.onTriggerRecovery,
    required this.onCompleted,
    required this.currentLives,
  });

  @override
  State<DilutionSimulation> createState() => _DilutionSimulationState();
}

class _DilutionSimulationState extends State<DilutionSimulation> {
  double _c1 = 2.0; // Initial Stock Molarity (M)
  double _v1 = 50.0; // Initial Volume (mL)
  double _addedSolvent = 50.0; // Distilled water added (mL)
  final TextEditingController _predictionController = TextEditingController();
  ActivityEvaluationResult? _lastEvaluation;
  bool _evaluated = false;

  double get _totalVolume => _v1 + _addedSolvent;
  double get _theoreticalFinalMolarity => (_c1 * _v1) / _totalVolume;

  void _evaluatePrediction() {
    final text = _predictionController.text.trim();
    final double? predicted = double.tryParse(text);

    if (predicted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid numeric value for final concentration.',
          ),
        ),
      );
      return;
    }

    Map<String, String> misconceptions = {};
    if (predicted > _c1) {
      misconceptions['dilution_increases_concentration'] = 'Dilution with solvent CANNOT increase solute concentration. Adding water decreases molarity.';
    } else if ((predicted - (_c1 * _v1 / _addedSolvent)).abs() < 0.1 &&
        _addedSolvent != _totalVolume) {
      misconceptions['divided_by_added_not_total'] = 'You divided by added solvent instead of total final volume V₂ = V₁ + ΔV.';
    }

    final eval = ActivityEvaluationResult.evaluateNumeric(
      prediction: predicted,
      expected: _theoreticalFinalMolarity,
      tolerancePercent: 0.05,
      unit: 'M',
      formulaName: 'Dilution Conservation: C₁V₁ = C₂V₂',
      commonMisconceptions: misconceptions,
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

  void _resetParams() {
    setState(() {
      _c1 = 2.0;
      _v1 = 50.0;
      _addedSolvent = 50.0;
      _evaluated = false;
      _lastEvaluation = null;
      _predictionController.clear();
    });
  }

  @override
  void dispose() {
    _predictionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fillPercent = (_totalVolume / 350.0).clamp(0.1, 0.95);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Virtual Model Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCCFBF1)),
          ),
          child: const Row(
            children: [
              Icon(Icons.science_rounded, color: Color(0xFF0D9488), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Virtual Mathematical Model: Conservation of Solute (C₁V₁ = C₂V₂)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF115E59),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Visual Beaker Rendering
        Center(
          child: Container(
            height: 170,
            width: 140,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: BeakerPainter(
                volumePercent: fillPercent,
                concentration: _theoreticalFinalMolarity,
                baseSolutionColor: const Color(0xFF0D9488),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Total Volume: ${_totalVolume.toStringAsFixed(0)} mL | Molarity: ${_theoreticalFinalMolarity.toStringAsFixed(2)} M',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3C58),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Parameter Sliders
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
                      'Stock Molarity (C₁): ${_c1.toStringAsFixed(1)} M',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      'Moles = C₁ × V₁',
                      style: TextStyle(fontSize: 11, color: Color(0xFF56667F)),
                    ),
                  ],
                ),
                Slider(
                  value: _c1,
                  min: 0.5,
                  max: 5.0,
                  divisions: 45,
                  label: '${_c1.toStringAsFixed(1)} M',
                  onChanged: (val) {
                    setState(() {
                      _c1 = val;
                      _evaluated = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Initial Stock Volume (V₁): ${_v1.toStringAsFixed(0)} mL',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Slider(
                  value: _v1,
                  min: 10.0,
                  max: 150.0,
                  divisions: 14,
                  label: '${_v1.toStringAsFixed(0)} mL',
                  onChanged: (val) {
                    setState(() {
                      _v1 = val;
                      _evaluated = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Added Solvent / Water (ΔV): ${_addedSolvent.toStringAsFixed(0)} mL',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Slider(
                  value: _addedSolvent,
                  min: 0.0,
                  max: 200.0,
                  divisions: 20,
                  label: '${_addedSolvent.toStringAsFixed(0)} mL',
                  onChanged: (val) {
                    setState(() {
                      _addedSolvent = val;
                      _evaluated = false;
                    });
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _resetParams,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Reset Parameters',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
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
                  'Dilution Molarity Prediction',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Given C₁ = ${_c1.toStringAsFixed(1)} M, V₁ = ${_v1.toStringAsFixed(0)} mL, and total V₂ = ${_totalVolume.toStringAsFixed(0)} mL, calculate final concentration C₂:',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF46566F),
                  ),
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
                          hintText: 'e.g. 1.00',
                          suffixText: 'Molar (M)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      key: const Key('practiverse-check'),
                      onPressed: _evaluatePrediction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
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
}
