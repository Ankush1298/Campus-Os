import 'generated_practical.dart';
import 'practical_activity.dart';

/// The student-facing explanation shown at the top of every practical, in one consistent structure.
class PracticalBrief {
  final String objective;
  final String task;
  final List<String> steps;
  final String inputs;
  final String expected;
  final String validation;
  final String notice; // honest statement of what this practical is (a software model, a real runner, ...)

  const PracticalBrief({
    required this.objective,
    required this.task,
    required this.steps,
    required this.inputs,
    required this.expected,
    required this.validation,
    required this.notice,
  });
}

class PracticalBriefs {
  static PracticalBrief of(PracticalActivity a) {
    final g = a.generated;
    if (g != null) {
      return PracticalBrief(
        objective: g.objective,
        task: g.model != null ? 'Work out the ${g.model!.resultName.toLowerCase()} for the values shown.' : g.task,
        steps: g.steps,
        inputs: g.inputs,
        expected: g.expected,
        validation: g.model != null
            ? 'Your numeric answer is checked against the value computed from the formula (within 5%). If you miss it, a short quiz on the theory comes next.'
            : (g.scenario != null
                ? 'Your decisions are scored by the app (60% to pass). If you miss it, a short quiz on the theory comes next.'
                : 'The questions are scored by the app (60% to pass). If you miss it, you re-read the theory and retry.'),
        notice: '${GeneratedPractical.flowNote}\n${g.sourceLabel}',
      );
    }
    return _byId[a.id] ?? _fallback(a);
  }

  static PracticalBrief _fallback(PracticalActivity a) => PracticalBrief(
    objective: a.objective,
    task:
        'Work through the linked virtual lab and answer the verification quiz.',
    steps: const [
      'Open the virtual lab link below in your browser.',
      'Follow the lab instructions and note what you observe.',
      'Come back and take the verification quiz.',
    ],
    inputs: 'Controls inside the external lab.',
    expected: 'The behaviour described in the lab description.',
    validation: 'The quiz is scored automatically; this app does not see what you do inside the external lab.',
    notice: 'External virtual lab: opens outside CampusOS and is not evaluated by this app.',
  );

  static const Map<String, PracticalBrief> _byId = {
    'physics_ohms_law': PracticalBrief(
      objective: "Understand Ohm's law: for a fixed resistor, the current through it is proportional to the voltage across it and inversely proportional to its resistance.",
      task: 'For the voltage V and resistance R shown, calculate the current I in amperes, then explain from the graph what happens to I when R increases.',
      steps: [
        'Move the Voltage and Resistance sliders and watch the circuit and the graphs update (or press Randomize).',
        'Use I = V / R to work out the current for the displayed V and R. Write it down with its unit (A).',
        'Type your answer in the box and press Verify.',
        'Now double R and look at the V-I graph: the line gets flatter, because the same voltage drives half the current.',
      ],
      inputs: 'Voltage 1 to 30 V and resistance 1 to 50 Ω (resistance cannot be 0: that would make the current undefined).',
      expected: 'Current in amperes. The V-I graph is a straight line through the origin with slope 1/R; the I-R graph falls as R grows.',
      validation: 'Correct when your answer is within 5% of V / R. A wrong answer costs one life and unlocks the next hint.',
      notice: 'Software model of an ideal resistor, not a real physical experiment.',
    ),
    'math_statistics_data': PracticalBrief(
      objective: 'See why the mean is pulled by extreme values while the median stays stable.',
      task: 'Look at the sorted dataset and calculate its exact median, then add an outlier and compare how the mean and the median react.',
      steps: [
        'Read the numbers in the sorted dataset.',
        'Add or remove values with the dataset controls (try one very large number).',
        'Compare the Arithmetic Mean and Positional Median cards.',
        'Type the median of the current dataset and press Verify.',
      ],
      inputs: 'Numbers you add to the dataset.',
      expected: 'The middle value of the sorted data (average of the two middle values when the count is even).',
      validation: 'Correct when your answer equals the median within a tiny tolerance. A wrong answer costs one life.',
      notice: 'Software model with deterministic checking.',
    ),
    'chemistry_dilution': PracticalBrief(
      objective: 'Learn that diluting a solution keeps the amount of solute constant while the concentration drops: C1 × V1 = C2 × V2.',
      task: 'Given the stock concentration C1, the stock volume V1 and the total volume V2 after adding solvent, calculate the final concentration C2.',
      steps: [
        'Adjust the stock concentration and the amount of solvent added.',
        'Compute C2 = (C1 × V1) / V2.',
        'Type C2 in molar (M) and press Verify.',
      ],
      inputs: 'Stock molarity C1, stock volume V1, added solvent volume.',
      expected:
          'A concentration lower than C1 (adding solvent can never raise it).',
      validation: 'Correct when your answer is within 5% of the exact C2. A wrong answer costs one life.',
      notice: 'Software model, not a physical experiment.',
    ),
    'cs_sum_two_numbers': PracticalBrief(
      objective: 'Write a function that returns the sum of two integers.',
      task: 'Implement `int solve(int a, int b)` in Dart so it returns a + b for every input.',
      steps: [
        'Read the problem statement, input/output format and constraints.',
        'Write your solution in the editor (typing only: paste is disabled during practicals).',
        'Press Run to check the visible test cases. Fix any compile or runtime errors shown.',
        'Press Submit when you are ready: your code is also checked against hidden tests.',
      ],
      inputs: 'Your Dart code.',
      expected:
          'solve(2, 3) returns 5 and every other case returns the true sum.',
      validation: 'Your code is really compiled and run on every test. You pass only when ALL visible and hidden tests return the exact expected output.',
      notice: 'Real code execution: Dart, interpreted in an isolated sandbox inside the app (no files or network, 3-second limit per test).',
    ),
    'cs_even_or_odd': PracticalBrief(
      objective: 'Use the remainder operator (%) to decide whether a number is even or odd.',
      task:
          "Implement `String solve(int n)` returning exactly 'Even' or 'Odd'.",
      steps: [
        'Read the statement and examples.',
        'Write your solution in the editor.',
        'Press Run to check the visible tests and read any errors.',
        'Press Submit to also run the hidden tests.',
      ],
      inputs: 'Your Dart code.',
      expected: "solve(4) is 'Even', solve(7) is 'Odd', solve(0) is 'Even', and negatives work too.",
      validation: 'Pass = every visible and hidden test returns exactly the expected text.',
      notice: 'Real code execution: Dart, interpreted in an isolated sandbox inside the app (no files or network, 3-second limit per test).',
    ),
    'cs_reverse_string': PracticalBrief(
      objective:
          'Practise string handling by reversing the order of characters.',
      task: 'Implement `String solve(String s)` returning s reversed.',
      steps: [
        'Read the statement and examples.',
        'Write your solution in the editor.',
        'Press Run to check the visible tests and read any errors.',
        'Press Submit to also run the hidden tests.',
      ],
      inputs: 'Your Dart code.',
      expected: "solve('campus') is 'supmac'; a palindrome stays unchanged; the empty string stays empty.",
      validation: 'Pass = every visible and hidden test returns exactly the expected text.',
      notice: 'Real code execution: Dart, interpreted in an isolated sandbox inside the app (no files or network, 3-second limit per test).',
    ),
  };
}
