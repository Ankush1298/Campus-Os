import 'package:flutter/material.dart';

import '../../models/practical_activity.dart';
import '../../models/activity_evaluation.dart';
import '../../widgets/circuit_diagram_painter.dart';

class OhmsLawSimulation extends StatefulWidget {
  final PracticalActivity activity;
  final VoidCallback onLifeDeducted;
  final VoidCallback onUnlockHint;
  final VoidCallback onTriggerRecovery;
  final VoidCallback onCompleted;
  final int currentLives;

  const OhmsLawSimulation({
    super.key,
    required this.activity,
    required this.onLifeDeducted,
    required this.onUnlockHint,
    required this.onTriggerRecovery,
    required this.onCompleted,
    required this.currentLives,
  });

  @override
  State<OhmsLawSimulation> createState() => _OhmsLawSimulationState();
}

class _OhmsLawSimulationState extends State<OhmsLawSimulation> {
  double _voltage = 12.0; // Volts
  double _resistance =
      6.0; // Ohms (strictly >= 1.0 to prevent division by zero)
  final TextEditingController _predictionController = TextEditingController();
  ActivityEvaluationResult? _lastEvaluation;
  bool _evaluated = false;

  double get _theoreticalCurrent => _voltage / _resistance;

  void _evaluatePrediction() {
    final text = _predictionController.text.trim();
    final double? predicted = double.tryParse(text);

    if (predicted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid numeric value for Current (Amperes).',
          ),
        ),
      );
      return;
    }

    // Misconception identification
    Map<String, String> misconceptions = {};
    if ((predicted - (_voltage * _resistance)).abs() < 1.0) {
      misconceptions['multiplication_misconception'] = 'You multiplied V × R. Remember that resistance OPPOSES current, so I = V / R.';
    } else if ((predicted - _voltage).abs() < 0.2 && _resistance != 1.0) {
      misconceptions['ignored_resistance'] = 'You assumed current equals voltage. Resistance restricts the electron flow.';
    }

    final eval = ActivityEvaluationResult.evaluateNumeric(
      prediction: predicted,
      expected: _theoreticalCurrent,
      tolerancePercent: 0.05,
      unit: 'A',
      formulaName: "Ohm's Law: I = V / R",
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
        // Next life is 0
        widget.onTriggerRecovery();
      }
    }
  }

  void _randomizeParams() {
    setState(() {
      _voltage = ((DateTime.now().millisecond % 24) + 6).toDouble();
      _resistance = (((DateTime.now().microsecond % 15) + 3)).toDouble();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Virtual Model Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Virtual Mathematical Model: I = V / R (Ideal DC Conductor)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Circuit Schematic Canvas
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: CustomPaint(
            painter: CircuitDiagramPainter(
              voltage: _voltage,
              resistance: _resistance,
              current: _theoreticalCurrent,
              accentColor: const Color(0xFF2563EB),
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
                      'Battery Voltage (V): ${_voltage.toStringAsFixed(1)} V',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                  ],
                ),
                Slider(
                  value: _voltage,
                  min: 1.0,
                  max: 30.0,
                  divisions: 29,
                  label: '${_voltage.toStringAsFixed(1)} V',
                  onChanged: (val) {
                    setState(() {
                      _voltage = val;
                      _evaluated = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resistance (R): ${_resistance.toStringAsFixed(1)} Ω',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      'Non-zero (R ≥ 1Ω)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Slider(
                  value: _resistance,
                  min: 1.0,
                  max: 50.0,
                  divisions: 49,
                  label: '${_resistance.toStringAsFixed(1)} Ω',
                  onChanged: (val) {
                    setState(() {
                      _resistance = val;
                      _evaluated = false;
                    });
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _randomizeParams,
                    icon: const Icon(Icons.shuffle_rounded, size: 16),
                    label: const Text(
                      'Randomize Parameters',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Prediction Input & Tolerance Checker
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theoretical Prediction Challenge',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Given V = ${_voltage.toStringAsFixed(1)} V and R = ${_resistance.toStringAsFixed(1)} Ω, predict the resulting current (I) in Amperes:',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
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
                          hintText: 'e.g. 2.00',
                          suffixText: 'Amperes (A)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      key: const Key('practiverse-check'),
                      onPressed: _evaluatePrediction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
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

        // Evaluation Outcome & Misconception Analysis
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
                        color: Color(0xFF334155),
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
