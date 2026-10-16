import 'package:flutter/material.dart';

/// Represents an academic or scientific subject discipline supported in PractiVerse.
enum SubjectCategory {
  physics,
  chemistry,
  mathematics,
  computerScience,
  biology,
  economics,
}

class PracticalSubject {
  final String id;
  final String name;
  final SubjectCategory category;
  final IconData icon;
  final Color accentColor;
  final String description;
  final List<String> sampleTopics;
  final bool hasInteractiveSimulations;

  const PracticalSubject({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.description,
    required this.sampleTopics,
    this.hasInteractiveSimulations = true,
  });

  static const List<PracticalSubject> defaultSubjects = [
    PracticalSubject(
      id: 'physics',
      name: 'Physics & Electronics',
      category: SubjectCategory.physics,
      icon: Icons.electric_bolt_rounded,
      accentColor: Color(0xFF0E7C86),
      description: 'Circuit behavior, Ohm\'s law, electromagnetic induction, wave mechanics, and optics.',
      sampleTopics: [
        'Ohm\'s Law & DC Circuits',
        'Kirchhoff\'s Circuit Laws',
        'Simple Harmonic Motion',
        'Refraction & Snell\'s Law',
      ],
    ),
    PracticalSubject(
      id: 'mathematics',
      name: 'Mathematics & Statistics',
      category: SubjectCategory.mathematics,
      icon: Icons.functions_rounded,
      accentColor: Color(0xFF5A6AE8),
      description: 'Statistical distributions, central tendency, outliers, linear regression, and calculus.',
      sampleTopics: [
        'Descriptive Statistics & Outliers',
        'Normal Distribution & Z-Scores',
        'Matrix Transformations',
        'Calculus: Derivatives & Slopes',
      ],
    ),
    PracticalSubject(
      id: 'chemistry',
      name: 'Chemistry & Materials',
      category: SubjectCategory.chemistry,
      icon: Icons.science_rounded,
      accentColor: Color(0xFF0D9488),
      description: 'Solution concentrations, dilutions, acid-base titrations, and chemical kinetics.',
      sampleTopics: [
        'Solution Dilution & Concentration',
        'Acid-Base Titration Curves',
        'Boyle\'s Law & Gas Thermodynamics',
        'Reaction Rates & Catalysts',
      ],
    ),
    PracticalSubject(
      id: 'computer_science',
      name: 'Computer Science & Logic',
      category: SubjectCategory.computerScience,
      icon: Icons.code_rounded,
      accentColor: Color(0xFF0284C7),
      description: 'Data structures, algorithm complexity, control flow, and automated verification.',
      sampleTopics: [
        'Sum Two Numbers (Arithmetic & Logic)',
        'Even or Odd (Parity & Modulo)',
        'Reverse a String (Pointers & Array reversal)',
        'Binary Search Simulation',
      ],
    ),
    PracticalSubject(
      id: 'biology',
      name: 'Biology & Life Sciences',
      category: SubjectCategory.biology,
      icon: Icons.biotech_rounded,
      accentColor: Color(0xFF16A34A),
      description: 'Cell osmosis, enzyme kinetics, Mendelian genetics, and population dynamics.',
      sampleTopics: [
        'Cell Osmosis & Tonicity',
        'Enzyme Reaction Velocity (Michaelis-Menten)',
        'Punnett Squares & Genetic Crosses',
      ],
      hasInteractiveSimulations: false,
    ),
    PracticalSubject(
      id: 'economics',
      name: 'Economics & Commerce',
      category: SubjectCategory.economics,
      icon: Icons.trending_up_rounded,
      accentColor: Color(0xFFD97706),
      description: 'Supply and demand equilibrium, elasticity of pricing, and cost-volume-profit analysis.',
      sampleTopics: [
        'Market Supply & Demand Equilibrium',
        'Price Elasticity of Demand',
        'Compound Interest & Net Present Value',
      ],
      hasInteractiveSimulations: false,
    ),
  ];
}
