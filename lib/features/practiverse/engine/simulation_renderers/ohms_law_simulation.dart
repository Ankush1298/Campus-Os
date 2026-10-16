import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/practical_activity.dart';
import '../../models/activity_evaluation.dart';
import '../../widgets/circuit_diagram_painter.dart';
import '../../widgets/line_chart.dart';

/// Pure model behind the Ohm's-law practical (also what the unit tests check).
class OhmsLawModel {
  static const double vMax = 30;
  static const double rMax = 50;

  /// I = V / R, or null when the inputs make no physical sense (R <= 0 would be a short circuit: undefined).
  static double? current(double v, double r) =>
      (v.isFinite && r.isFinite && r > 0) ? v / r : null;

  /// Points of the V-I line at a fixed resistance: (voltage, current).
  static List<Offset> voltageCurrent(double r, {int steps = 6}) => [
    for (var i = 0; i <= steps; i++)
      Offset(vMax * i / steps, current(vMax * i / steps, r) ?? 0),
  ];

  /// Points of the I-R curve at a fixed voltage: (resistance, current).
  static List<Offset> currentResistance(double v) => [
    for (var r = 1; r <= rMax; r++)
      Offset(r.toDouble(), current(v, r.toDouble()) ?? 0),
  ];

  static double niceCeil(double v) {
    if (v <= 0) return 1;
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * p >= v) return m * p;
    }
    return 10 * p;
  }
}

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

  double get _theoreticalCurrent =>
      OhmsLawModel.current(_voltage, _resistance) ?? 0;

  void _evaluatePrediction() {
    final text = _predictionController.text.trim();
    final double? predicted = double.tryParse(text);

    if (predicted == null || !predicted.isFinite || predicted < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid, non-negative number for the current (in amperes).',
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
            color: const Color(0xFFE6F4F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFB3DFE4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Color(0xFF0E7C86), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Virtual Mathematical Model: I = V / R (Ideal DC Conductor)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0B5F68),
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
              accentColor: const Color(0xFF0E7C86),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Graphs: real computed data (updates with every slider move)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledLineChart(
                  key: const Key('ohm-graph-vi'),
                  title:
                      'Graph 1: Current vs Voltage (R = ${_resistance.toStringAsFixed(1)} Ω)',
                  xLabel: 'Voltage V (volts)',
                  yLabel: 'Current I (amperes)',
                  xMax: OhmsLawModel.vMax,
                  yMax: OhmsLawModel.niceCeil(OhmsLawModel.vMax / _resistance),
                  series: [
                    ChartSeries(
                      label:
                          'I = V / R at R = ${_resistance.toStringAsFixed(1)} Ω',
                      points: OhmsLawModel.voltageCurrent(_resistance),
                      color: const Color(0xFF0E7C86),
                      showPoints: true,
                    ),
                    ChartSeries(
                      label: 'Resistance doubled (2R)',
                      points: OhmsLawModel.voltageCurrent(_resistance * 2),
                      color: const Color(0xFF94A3B8),
                      dashed: true,
                    ),
                  ],
                  marker: Offset(_voltage, _theoreticalCurrent),
                  caption:
                      'Each dot is a voltage and the current it drives through this resistor. The line is straight because current is proportional to voltage; its steepness is 1/R. '
                      'The dashed line shows the same circuit with double the resistance: the same voltage drives half the current.',
                ),
                const Divider(height: 28),
                LabeledLineChart(
                  key: const Key('ohm-graph-ir'),
                  title:
                      'Graph 2: Current vs Resistance (V = ${_voltage.toStringAsFixed(1)} V)',
                  xLabel: 'Resistance R (ohms)',
                  yLabel: 'Current I (amperes)',
                  xMax: OhmsLawModel.rMax,
                  yMax: OhmsLawModel.niceCeil(_voltage),
                  series: [
                    ChartSeries(
                      label:
                          'I = V / R at V = ${_voltage.toStringAsFixed(1)} V',
                      points: OhmsLawModel.currentResistance(_voltage),
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                  marker: Offset(_resistance, _theoreticalCurrent),
                  caption: 'At a fixed voltage, more resistance means less current: the curve falls as R grows (inverse proportionality).',
                ),
                const SizedBox(height: 12),
                Container(
                  key: const Key('ohm-formula'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _evaluated
                        ? 'Formula: I = V / R = ${_voltage.toStringAsFixed(1)} V / ${_resistance.toStringAsFixed(1)} Ω = ${_theoreticalCurrent.toStringAsFixed(3)} A'
                        : 'Formula: I = V / R   (V = ${_voltage.toStringAsFixed(1)} V, R = ${_resistance.toStringAsFixed(1)} Ω, I = ? A. The calculated value is shown after you verify your answer.)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3C58),
                    ),
                  ),
                ),
              ],
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
                      style: TextStyle(fontSize: 11, color: Color(0xFF56667F)),
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
                        backgroundColor: const Color(0xFF0E7C86),
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
