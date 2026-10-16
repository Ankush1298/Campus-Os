import '../models/practical_subject.dart';
import '../models/topic_intake_result.dart';
import 'activity_registry.dart';

class TopicIntakeEngine {
  /// Analyzes arbitrary syllabus notes, text, or a topic title to extract key
  /// academic concepts and match them with relevant simulations and lab activities.
  static TopicIntakeResult analyzeText(String input) {
    final lower = input.toLowerCase();

    // 1. Scoring subjects based on keyword occurrences
    int physicsScore = _countMatches(lower, [
      'ohm',
      'volt',
      'ampere',
      'current',
      'circuit',
      'resistor',
      'resistance',
      'electricity',
      'potential',
      'physics',
      'electromagnetism',
      'dc',
    ]);

    int mathScore = _countMatches(lower, [
      'mean',
      'median',
      'mode',
      'outlier',
      'statistics',
      'distribution',
      'variance',
      'standard deviation',
      'math',
      'calculus',
      'data',
      'analytics',
    ]);

    int chemScore = _countMatches(lower, [
      'dilution',
      'concentration',
      'molarity',
      'solute',
      'solvent',
      'solution',
      'titration',
      'chemistry',
      'acid',
      'base',
      'moles',
      'c1v1',
    ]);

    int csScore = _countMatches(lower, [
      'code',
      'algorithm',
      'function',
      'programming',
      'array',
      'loop',
      'computer science',
      'software',
      'reverse',
      'even',
      'odd',
      'sum',
      'dart',
    ]);

    int bioScore = _countMatches(lower, [
      'cell',
      'osmosis',
      'biology',
      'membrane',
      'diffusion',
      'tonicity',
      'microscope',
    ]);

    int econScore = _countMatches(lower, [
      'supply',
      'demand',
      'economics',
      'market',
      'equilibrium',
      'price',
      'cost',
    ]);

    // Determine leading subject
    String chosenSubjectId = 'physics';
    int maxScore = physicsScore;

    if (mathScore > maxScore) {
      maxScore = mathScore;
      chosenSubjectId = 'mathematics';
    }
    if (chemScore > maxScore) {
      maxScore = chemScore;
      chosenSubjectId = 'chemistry';
    }
    if (csScore > maxScore) {
      maxScore = csScore;
      chosenSubjectId = 'computer_science';
    }
    if (bioScore > maxScore) {
      maxScore = bioScore;
      chosenSubjectId = 'biology';
    }
    if (econScore > maxScore) {
      maxScore = econScore;
      chosenSubjectId = 'economics';
    }

    final matchedSubject = PracticalSubject.defaultSubjects.firstWhere(
      (s) => s.id == chosenSubjectId,
      orElse: () => PracticalSubject.defaultSubjects.first,
    );

    final extractedConcepts = _extractConcepts(lower, matchedSubject.category);
    final recommended = ActivityRegistry.getBySubject(matchedSubject.id);

    final pedagogicalGuidance = _buildPedagogicalGuidance(
      matchedSubject,
      extractedConcepts,
    );

    final externalResources = recommended
        .where((a) => a.externalLab != null)
        .map((a) => a.externalLab!)
        .toList();

    return TopicIntakeResult(
      queryText: input,
      matchedSubject: matchedSubject,
      extractedKeyConcepts: extractedConcepts,
      recommendedActivities: recommended,
      pedagogicalGuidance: pedagogicalGuidance,
      externalResources: externalResources,
    );
  }

  static int _countMatches(String text, List<String> keywords) {
    int count = 0;
    for (final kw in keywords) {
      if (text.contains(kw)) count += 2;
    }
    return count;
  }

  static List<String> _extractConcepts(String text, SubjectCategory category) {
    final List<String> concepts = [];
    switch (category) {
      case SubjectCategory.physics:
        if (text.contains('ohm') ||
            text.contains('circuit') ||
            text.contains('resistance') ||
            text.isEmpty) {
          concepts.add("Ohm's Law: Current Proportionality (I = V/R)");
        }
        if (text.contains('volt') || text.contains('potential')) {
          concepts.add("Electromotive Force & Potential Difference");
        }
        if (text.contains('resistor') || text.contains('resistance')) {
          concepts.add("Ohmic Conductors & Resistance Dissipation");
        }
        if (concepts.isEmpty) {
          concepts.add("DC Circuit Analysis & Resistance");
        }
        break;
      case SubjectCategory.mathematics:
        if (text.contains('mean') || text.contains('average') || text.isEmpty) {
          concepts.add("Arithmetic Mean & Summation Measures");
        }
        if (text.contains('median') || text.contains('outlier')) {
          concepts.add("Median Resilience against Skewed Outliers");
        }
        if (text.contains('distribution') || text.contains('variance')) {
          concepts.add("Dispersion & Spread of Data");
        }
        if (concepts.isEmpty) {
          concepts.add("Central Tendency & Data Variation");
        }
        break;
      case SubjectCategory.chemistry:
        if (text.contains('dilution') ||
            text.contains('solvent') ||
            text.isEmpty) {
          concepts.add("Conservation of Solute in Dilution (C₁V₁ = C₂V₂)");
        }
        if (text.contains('concentration') || text.contains('molarity')) {
          concepts.add("Molar Concentration (moles/Litre)");
        }
        if (text.contains('titration') || text.contains('acid')) {
          concepts.add("Neutralization & Titration Stoichiometry");
        }
        if (concepts.isEmpty) {
          concepts.add("Solution Stoichiometry & Volumetric Analysis");
        }
        break;
      case SubjectCategory.computerScience:
        concepts.add("Algorithm Correctness & Logic Verification");
        concepts.add("Input Boundary Testing & Edge Cases");
        break;
      case SubjectCategory.biology:
        concepts.add("Osmotic Pressure & Selective Permeability");
        concepts.add("Hypertonic, Isotonic, and Hypotonic Tonicity");
        break;
      case SubjectCategory.economics:
        concepts.add("Market Equilibrium Price & Clearing Quantity");
        concepts.add("Supply & Demand Elasticity Shifts");
        break;
    }
    return concepts;
  }

  static String _buildPedagogicalGuidance(
    PracticalSubject subject,
    List<String> concepts,
  ) {
    return "Based on your syllabus intake for ${subject.name}, PractiVerse has structured an interactive experimental flow covering: ${concepts.join(', ')}. Engage with the mathematical simulations below, verify predictions with tolerance limits, and test conceptual retention.";
  }

  /// Curated sample syllabuses for instantaneous 1-tap demonstration.
  static const Map<String, String> sampleSyllabuses = {
    'Physics (Circuits)': '''
Course: Applied Physics & Electrical Engineering (PHY102)
Unit 2: DC Circuits and Electric Conduction
Topics:
- Electric current and drift velocity of electrons
- Ohm's law and experimental verification using ammeters and voltmeters
- Temperature dependence of resistance and internal resistance
- Series and parallel resistor networks
Learning Objectives: Verify current flow variations under changing voltage and resistance parameters.
''',
    'Mathematics (Statistics)': '''
Course: Discrete Mathematics & Engineering Statistics (MAT204)
Unit 3: Descriptive Statistics and Exploratory Data Analysis
Topics:
- Measures of central tendency: Mean, Median, Mode
- Robustness of positional measures vs arithmetic averages
- Outlier detection and sensitivity in real-world measurements
- Variance, standard deviation, and sample distributions
Learning Objectives: Understand how extreme outliers distort mean values compared to the median.
''',
    'Chemistry (Solutions)': '''
Course: General Chemistry & Chemical Analysis (CHM101)
Unit 1: Solution Preparation and Volumetric Stoichiometry
Topics:
- Concentration units: Molarity (M), molality, normality
- Stock solution dilution protocol: C1V1 = C2V2
- Solute mass balance and solvent addition dynamics
- Error analysis in volumetric pipetting and flask measurements
Learning Objectives: Predict final molarity following serial solvent additions.
''',
    'Computer Science (Algorithms)': '''
Course: Fundamentals of Programming & Computational Logic (CS101)
Unit 1: Core Operators and Algorithmic Thinking
Topics:
- Arithmetic expressions and return values
- Parity verification and modulo arithmetic
- Sequence traversal, pointers, and array reversal
- Automated test assertion and boundary edge cases
Learning Objectives: Implement robust logic functions and satisfy verification test suites.
''',
  };
}
