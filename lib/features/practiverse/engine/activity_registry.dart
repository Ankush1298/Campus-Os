import '../models/practical_activity.dart';

class ActivityRegistry {
  static const List<PracticalActivity> allActivities = [
    // 1. Physics / Electronics: Ohm's Law
    PracticalActivity(
      id: 'physics_ohms_law',
      subjectId: 'physics',
      title: "Ohm's Law & DC Circuits",
      conceptTested: 'Voltage-Current-Resistance Relationship (I = V / R)',
      difficulty: 'Beginner',
      objective: 'Predict the circuit current as voltage and resistance vary. Understand electron flow and proportional dynamics.',
      kind: ActivityKind.physicsOhmsLaw,
      formulaNotation: 'I = V / R',
      isVirtualSimulation: true,
      hints: [
        "Ohm's Law states that electric current (I) is directly proportional to voltage (V) and inversely proportional to resistance (R).",
        "The mathematical formula is I = V / R. Notice that as resistance increases, current decreases.",
        "Divide battery voltage in Volts by resistance in Ohms. Example: 12V / 4Ω = 3.00 Amperes.",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "If battery voltage remains constant at 12V and resistance is doubled from 4Ω to 8Ω, what happens to the electric current?",
          options: [
            "Current doubles to 6A",
            "Current is halved to 1.5A",
            "Current remains unchanged at 3A",
            "Current drops to 0A",
          ],
          correctIndex: 1,
          explanation: "According to I = V / R, current is inversely proportional to resistance. Doubling R cuts current in half.",
          misconceptionTarget: "inverse_proportionality",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question:
              "What standard SI unit is electrical resistance measured in?",
          options: ["Amperes (A)", "Volts (V)", "Ohms (Ω)", "Watts (W)"],
          correctIndex: 2,
          explanation:
              "Resistance is measured in Ohms (Ω), named after Georg Ohm.",
        ),
        DiagnosticQuizQuestion(
          question: "If a 24V supply is connected across a 12Ω resistor, what current flows?",
          options: ["0.5 A", "2.0 A", "12 A", "288 A"],
          correctIndex: 1,
          explanation: "Using I = V / R, 24V / 12Ω = 2.0 Amperes.",
        ),
      ],
      externalLab: ExternalLabResource(
        title: "Virtual Ohm's Law & Resistance Lab",
        url: "https://vlab.amrita.edu/?sub=1&brch=192&sim=546&cnt=1",
        provider: "Amrita Virtual Labs / Ministry of Education, GoI",
        description: "Official interactive virtual breadboard, potentiometer, and ammeter setup.",
      ),
    ),

    // 2. Mathematics / Statistics: Descriptive Statistics & Outliers
    PracticalActivity(
      id: 'math_statistics_data',
      subjectId: 'mathematics',
      title: "Descriptive Statistics & Outlier Impact",
      conceptTested: "Mean vs. Median Sensitivity & Central Tendency",
      difficulty: "Intermediate",
      objective: "Interactively modify datasets, calculate central measures, and observe how extreme values distort the mean while median stays resilient.",
      kind: ActivityKind.statisticsDataAnalysis,
      formulaNotation: "Mean = (Σx) / N, Median = Positional Center",
      isVirtualSimulation: true,
      hints: [
        "The arithmetic mean sums every number and divides by count: Mean = Σx / N.",
        "The median sorts the numbers and selects the middle value. For an even count, it averages the two center numbers.",
        "Notice what happens when an extreme outlier (e.g., 100) is introduced: the mean moves drastically, but the median moves little or none.",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "Which measure of central tendency is least sensitive to extreme outlier data points in a skewed distribution?",
          options: ["Arithmetic Mean", "Median", "Standard Deviation", "Range"],
          correctIndex: 1,
          explanation: "The median is robust against extreme values because it depends on positional rank rather than magnitude of extremes.",
          misconceptionTarget: "mean_vs_median_sensitivity",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question: "Given the dataset [3, 5, 7, 9, 11], what is the median?",
          options: ["5", "7", "9", "35"],
          correctIndex: 1,
          explanation:
              "For 5 ordered numbers, the 3rd number (7) is the exact median.",
        ),
        DiagnosticQuizQuestion(
          question: "If the number 150 is appended to [3, 5, 7, 9, 11], which metric shifts most dramatically?",
          options: ["Median", "Arithmetic Mean", "Mode", "None"],
          correctIndex: 1,
          explanation: "The mean surges from 7.0 to 30.8, whereas the median only shifts slightly to 8.0.",
        ),
      ],
      externalLab: ExternalLabResource(
        title: "Interactive Statistics & Distributions Lab",
        url: "https://phet.colorado.edu/en/simulations/plinko-probability",
        provider:
            "PhET Interactive Simulations, University of Colorado Boulder",
        description: "Simulate probability distributions, variance, and mean outcomes in real-time.",
      ),
    ),

    // 3. Chemistry: Solution Dilution
    PracticalActivity(
      id: 'chemistry_dilution',
      subjectId: 'chemistry',
      title: "Solution Dilution & Concentration",
      conceptTested: "Conservation of Solute (C₁V₁ = C₂V₂)",
      difficulty: "Intermediate",
      objective: "Adjust initial concentration and solvent volume to observe molecular density changes and calculate target molarity.",
      kind: ActivityKind.chemistryDilution,
      formulaNotation: "C₁ × V₁ = C₂ × V₂",
      isVirtualSimulation: true,
      hints: [
        "Dilution alters volume and molarity, but the moles of solute (n = C × V) remains constant.",
        "Use the formula C₁V₁ = C₂V₂ where V₂ = V₁ + added solvent.",
        "To find final concentration C₂: C₂ = (C₁ × V₁) / V₂.",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "When pure distilled water is added to a 2.0 M copper sulfate solution, what happens to the total moles of copper sulfate?",
          options: [
            "Total moles increase",
            "Total moles decrease",
            "Total moles remain unchanged",
            "Total moles drop to zero",
          ],
          correctIndex: 2,
          explanation: "Adding water only increases solvent volume. The quantity (moles) of dissolved solute remains identical.",
          misconceptionTarget: "solute_conservation",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question: "If 100 mL of 1.0 M NaCl is diluted by adding 100 mL of water (total volume 200 mL), what is the new molarity?",
          options: ["0.25 M", "0.50 M", "1.00 M", "2.00 M"],
          correctIndex: 1,
          explanation: "C₂ = (C₁V₁) / V₂ = (1.0 M × 100 mL) / 200 mL = 0.50 M.",
        ),
        DiagnosticQuizQuestion(
          question: "In standard laboratory chemistry, what is the unit of molarity (M)?",
          options: [
            "Grams per Liter",
            "Moles per Liter",
            "Milliliters per Gram",
            "Particles per Second",
          ],
          correctIndex: 1,
          explanation: "Molarity is defined as moles of solute per liter of solution (mol/L).",
        ),
      ],
      externalLab: ExternalLabResource(
        title: "Acid-Base Titration & Concentration Virtual Lab",
        url: "https://vlab.amrita.edu/?sub=2&brch=193&sim=352&cnt=1",
        provider: "Amrita Virtual Labs / Ministry of Education, GoI",
        description:
            "Standardize solutions and observe equivalence color transitions.",
      ),
    ),

    // 4. Computer Science Coding Challenges (Retained & Categorized)
    PracticalActivity(
      id: 'cs_sum_two_numbers',
      subjectId: 'computer_science',
      title: "Sum Two Numbers",
      conceptTested: "Arithmetic Operations & Variable Assignment",
      difficulty: "Beginner",
      objective: "Implement a function that accepts two integers and returns their sum.",
      kind: ActivityKind.codingChallenge,
      formulaNotation: "sum(a, b) = a + b",
      isVirtualSimulation: true,
      hints: [
        "In Dart or Python, functions return values using the return keyword.",
        "Simply add the two parameters together with the + operator.",
        "Syntax: return a + b;",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "What is the return type of a function that calculates the sum of two integers (e.g. 5 and 10)?",
          options: ["String", "int", "void", "bool"],
          correctIndex: 1,
          explanation: "The sum of two integers is always an integer (int).",
          misconceptionTarget: "data_types",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question: "What does the expression 7 + 15 evaluate to?",
          options: ["21", "22", "715", "8"],
          correctIndex: 1,
          explanation: "7 + 15 = 22.",
        ),
      ],
    ),

    PracticalActivity(
      id: 'cs_even_or_odd',
      subjectId: 'computer_science',
      title: "Even or Odd",
      conceptTested: "Modulo Arithmetic & Parity Logic",
      difficulty: "Beginner",
      objective: "Determine whether an integer is divisible by 2 using the remainder operator (%).",
      kind: ActivityKind.codingChallenge,
      formulaNotation: "n % 2 == 0",
      isVirtualSimulation: true,
      hints: [
        "The modulo operator % returns the integer remainder after division.",
        "An even number leaves remainder 0 when divided by 2: n % 2 == 0.",
        "If n % 2 == 0 return 'Even', else return 'Odd'.",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "What does the expression 9 % 2 evaluate to?",
          options: ["0", "1", "4.5", "4"],
          correctIndex: 1,
          explanation: "9 divided by 2 is 4 with a remainder of 1. Hence 9 % 2 = 1 (Odd).",
          misconceptionTarget: "modulo_arithmetic",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question: "Which of the following numbers is an even number?",
          options: ["13", "27", "42", "99"],
          correctIndex: 2,
          explanation: "42 is divisible by 2 with 0 remainder (42 % 2 == 0).",
        ),
      ],
    ),

    PracticalActivity(
      id: 'cs_reverse_string',
      subjectId: 'computer_science',
      title: "Reverse a String",
      conceptTested: "String Indexing, Pointers, and Character Sequences",
      difficulty: "Intermediate",
      objective: "Reverse character order of an input string.",
      kind: ActivityKind.codingChallenge,
      formulaNotation: "s.split('').reversed.join('')",
      isVirtualSimulation: true,
      hints: [
        "A string is a sequence of characters.",
        "You can split into characters, reverse the iterable, and join back.",
        "In Dart: input.split('').reversed.join('');",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "If the string 'campus' is reversed, what is its first character?",
          options: ["c", "p", "s", "u"],
          correctIndex: 2,
          explanation: "Reversing 'campus' yields 'supmac', whose first character is 's'.",
          misconceptionTarget: "string_indexing",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question: "What is the reverse of the string 'radar'?",
          options: ["radar", "darar", "radra", "aradr"],
          correctIndex: 0,
          explanation: "'radar' is a palindrome; its reverse is identical.",
        ),
      ],
    ),

    // 5. Biology & Life Sciences: Virtual Lab
    PracticalActivity(
      id: 'bio_osmosis',
      subjectId: 'biology',
      title: "Cell Osmosis & Tonicity",
      conceptTested: "Water Potential & Semi-Permeable Membrane Diffusion",
      difficulty: "Beginner",
      objective: "Observe animal and plant cells in hypotonic, isotonic, and hypertonic solutions.",
      kind: ActivityKind.externalVirtualLab,
      formulaNotation: "Ψ = Ψs + Ψp",
      isVirtualSimulation: true,
      hints: [
        "Water travels from regions of lower solute concentration (higher water potential) to higher solute concentration.",
        "In a hypertonic solution, water leaves the cell causing crenation or plasmolysis.",
      ],
      recoveryQuestions: [
        RecoveryQuestion(
          question: "When a red blood cell is placed in pure distilled water (hypotonic solution), what happens?",
          options: [
            "It shrinks (crenates)",
            "Water enters and it swells/bursts (lysis)",
            "It remains completely unchanged",
            "It turns into a plant cell",
          ],
          correctIndex: 1,
          explanation: "Because the cell interior has higher solute concentration, water rushes in, causing lysis.",
          misconceptionTarget: "osmotic_pressure",
        ),
      ],
      diagnosticQuizQuestions: [
        DiagnosticQuizQuestion(
          question: "What is osmosis?",
          options: [
            "Movement of solutes across a membrane",
            "Net diffusion of water molecules through a semi-permeable membrane",
            "Active transport requiring ATP",
            "Evaporation of water",
          ],
          correctIndex: 1,
          explanation: "Osmosis specifically refers to the diffusion of water solvent across a selectively permeable barrier.",
        ),
      ],
      externalLab: ExternalLabResource(
        title: "Cell Biology & Osmosis Virtual Laboratory",
        url: "https://vlab.amrita.edu/?sub=3&brch=187&sim=327&cnt=1",
        provider: "Amrita Virtual Labs / Ministry of Education, GoI",
        description: "Live microscope view of plant cells under varying sucrose solutions.",
      ),
    ),
  ];

  static List<PracticalActivity> getBySubject(String subjectId) {
    return allActivities.where((a) => a.subjectId == subjectId).toList();
  }

  static PracticalActivity? getById(String id) {
    try {
      return allActivities.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
