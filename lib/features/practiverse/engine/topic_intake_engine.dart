import '../models/practical_activity.dart';
import '../models/practical_subject.dart';
import '../models/topic_intake_result.dart';
import 'activity_registry.dart';

/// Matches a topic title, chapter notes or a syllabus to the practicals PractiVerse really has.
///
/// This is deterministic keyword matching (not AI). What makes it dependable:
///  * whole-word matching: "mode" never fires inside "model", "dc" never inside "medicine";
///  * plurals and a few stems ("resist*" covers resistor, resistance, resistive);
///  * typographic apostrophes (Ohm’s) and case are normalised;
///  * every syllabus line / bullet is mapped to a practical on its own, so the student sees which topic
///    is covered by what;
///  * when nothing matches it says so (and lists every practical), instead of guessing "Physics";
///  * topics PractiVerse recognises but has no practical for are listed as such.
class TopicIntakeEngine {
  static const double matchThreshold = 1.5;

  /// Terms per practical. 'word' = exact token (plural tolerated), 'stem*' = prefix, spaces = phrase.
  /// Strong terms are specific to the practical (weight 1.5, phrases 3); weak terms are common words (0.75).
  static const Map<String, _Terms> _rules = {
    'physics_ohms_law': _Terms(
      strong: ['ohm', "ohm's", 'ohms', 'voltage', 'volt', 'voltmeter', 'ammeter', 'ampere', 'amp', 'resist*', 'circuit', 'conductor', 'drift velocity', 'potential difference', 'emf', 'electric current', 'i=v/r', 'v=ir', 'rheostat', 'galvanometer'],
      weak: ['current', 'dc', 'electricity', 'electrical', 'series', 'parallel', 'battery', 'wire', 'physics'],
      phrases: ["ohm's law", 'ohm law', 'ohms law', 'dc circuit', 'series and parallel', 'electric current', 'potential difference', 'drift velocity'],
    ),
    'math_statistics_data': _Terms(
      strong: ['median', 'outlier', 'variance', 'statistics', 'statistical', 'skewness', 'skewed', 'histogram', 'quartile', 'percentile', 'dispersion', 'central tendency', 'standard deviation', 'average', 'descriptive'],
      weak: ['mean', 'mode', 'data', 'distribution', 'sample', 'analytics', 'math', 'mathematics', 'probability'],
      phrases: ['standard deviation', 'central tendency', 'descriptive statistics', 'data analysis', 'measures of central', 'box plot'],
    ),
    'chemistry_dilution': _Terms(
      strong: ['dilution', 'dilute', 'diluted', 'molarity', 'molar', 'molality', 'normality', 'solute', 'solvent', 'titration', 'titrate', 'pipette', 'pipetting', 'volumetric', 'stoichiometry', 'c1v1', 'c1v1=c2v2', 'aliquot'],
      weak: ['concentration', 'solution', 'solutions', 'acid', 'base', 'mole', 'moles', 'chemistry', 'aqueous', 'reagent'],
      phrases: ['stock solution', 'serial dilution', 'c1 v1', 'c1v1 = c2v2', 'c1v1', 'acid base'],
    ),
    'cs_sum_two_numbers': _Terms(
      strong: ['addition', 'arithmetic', 'return value', 'return values', 'sum of two', 'add two numbers', 'operator', 'operators', 'expression', 'expressions'],
      weak: ['sum', 'add', 'variable', 'variables', 'integer', 'integers', 'function', 'functions', 'return'],
      phrases: ['sum of two', 'add two numbers', 'arithmetic expression', 'arithmetic expressions', 'return value', 'return values', 'sum two numbers'],
    ),
    'cs_even_or_odd': _Terms(
      strong: ['parity', 'modulo', 'modulus', 'remainder', 'divisible', 'divisibility', 'even or odd', 'odd or even', 'conditional', 'conditionals'],
      weak: ['even', 'odd', 'if', 'else', 'branching', 'condition', 'boolean'],
      phrases: ['even or odd', 'odd or even', 'modulo arithmetic', 'parity check', 'parity verification', 'remainder operator'],
    ),
    'cs_reverse_string': _Terms(
      strong: ['reverse', 'reversal', 'reversing', 'palindrome', 'palindromes', 'string', 'strings', 'substring', 'character', 'characters', 'pointer', 'pointers', 'array reversal', 'two pointer'],
      weak: ['array', 'arrays', 'sequence', 'traversal', 'index', 'indexing', 'text', 'list'],
      phrases: ['reverse a string', 'string reversal', 'array reversal', 'sequence traversal', 'string manipulation'],
    ),
    'bio_osmosis': _Terms(
      strong: ['osmosis', 'osmotic', 'tonicity', 'hypotonic', 'hypertonic', 'isotonic', 'plasmolysis', 'crenation', 'semipermeable', 'permeability', 'membrane', 'diffusion', 'lysis', 'turgor'],
      weak: ['cell', 'cells', 'biology', 'water potential', 'microscope', 'biological'],
      phrases: ['water potential', 'cell membrane', 'selective permeability', 'semi permeable'],
    ),
  };

  /// General programming vocabulary: counts toward Computer Science and lifts every coding practical.
  static const List<String> _csGeneral = ['code', 'coding', 'algorithm', 'algorithms', 'programming', 'software', 'dart', 'python', 'java', 'loop', 'loops', 'computer science', 'compiler', 'debugging', 'logic', 'test cases'];

  /// Topics PractiVerse recognises but has no practical for yet, with the closest existing practical (if any).
  static const List<_Unsupported> _unsupported = [
    _Unsupported('Kirchhoff\'s circuit laws', ['kirchhoff', 'kvl', 'kcl', 'loop rule', 'junction rule'], 'physics_ohms_law'),
    _Unsupported('Simple harmonic motion / waves', ['harmonic', 'pendulum', 'oscillation', 'oscillations', 'wave', 'waves', 'resonance'], null),
    _Unsupported('Optics: refraction / Snell\'s law', ['refraction', 'snell', 'snell\'s', 'lens', 'lenses', 'optics', 'reflection'], null),
    _Unsupported('Calculus (derivatives, integrals)', ['calculus', 'derivative', 'derivatives', 'integral', 'integrals', 'integration', 'differentiation', 'limits'], null),
    _Unsupported('Matrices / linear algebra', ['matrix', 'matrices', 'eigenvalue', 'eigenvalues', 'determinant', 'linear algebra'], null),
    _Unsupported('Probability distributions / z-scores', ['normal distribution', 'z-score', 'z score', 'binomial', 'poisson', 'hypothesis', 'regression'], 'math_statistics_data'),
    _Unsupported('Gas laws / thermodynamics', ['boyle', 'boyle\'s', 'charles', 'thermodynamics', 'enthalpy', 'entropy', 'ideal gas'], null),
    _Unsupported('Reaction kinetics / equilibrium', ['kinetics', 'catalyst', 'catalysts', 'reaction rate', 'le chatelier', 'equilibrium constant'], null),
    _Unsupported('Enzymes and genetics', ['enzyme', 'enzymes', 'michaelis', 'punnett', 'genetics', 'mendel', 'mendelian', 'allele', 'dna'], null),
    _Unsupported('Economics (supply & demand, elasticity)', ['supply', 'demand', 'elasticity', 'economics', 'market equilibrium', 'inflation', 'gdp'], null),
    _Unsupported('Data structures & algorithms (searching, sorting, trees)', ['binary search', 'sorting', 'quicksort', 'mergesort', 'linked list', 'stack', 'queue', 'tree', 'graph', 'recursion', 'complexity', 'big o'], null),
  ];

  // ------------------------------------------------------------------ normalising / matching
  static String _normalize(String input) {
    var t = input.toLowerCase().replaceAll(RegExp('[\u2018\u2019\u02BC`]'), "'");
    t = t.replaceAll(RegExp(r"[^a-z0-9'=/\s\-]"), ' ');
    return ' ${t.replaceAll(RegExp(r'\s+'), ' ').trim()} ';
  }

  static List<String> _tokens(String normalized) =>
      normalized.trim().isEmpty ? const [] : normalized.trim().split(' ').map((w) => w.replaceAll(RegExp(r"^[-']+|[-']+$"), '')).where((w) => w.isNotEmpty).toList();

  static bool _tokenMatches(String token, String term) {
    // "Kirchhoff's" / "Ohm's" also count as "kirchhoff" / "ohm".
    if (token.endsWith("'s") && token.length > 2 && _tokenMatchesExact(token.substring(0, token.length - 2), term)) return true;
    return _tokenMatchesExact(token, term);
  }

  static bool _tokenMatchesExact(String token, String term) {
    if (term.endsWith('*')) {
      final stem = term.substring(0, term.length - 1);
      return token.length >= stem.length && token.startsWith(stem);
    }
    return token == term || token == '${term}s' || token == '${term}es' || (term.endsWith('y') && token == '${term.substring(0, term.length - 1)}ies');
  }

  /// Terms of [terms] present in [normalized] text, with their weights. Each term counts once.
  static Map<String, double> _hits(String normalized, List<String> tokens, _Terms terms) {
    final hits = <String, double>{};
    for (final p in terms.phrases) {
      if (normalized.contains(' $p ') || normalized.contains(' ${p}s ')) hits[p] = 3.0;
    }
    for (final w in terms.strong) {
      if (w.contains(' ')) {
        if (normalized.contains(' $w ')) hits.putIfAbsent(w, () => 1.5);
      } else if (tokens.any((t) => _tokenMatches(t, w))) {
        hits.putIfAbsent(w, () => 1.5);
      }
    }
    for (final w in terms.weak) {
      if (w.contains(' ')) {
        if (normalized.contains(' $w ')) hits.putIfAbsent(w, () => 0.75);
      } else if (tokens.any((t) => _tokenMatches(t, w))) {
        hits.putIfAbsent(w, () => 0.75);
      }
    }
    return hits;
  }

  /// Strong terms and phrases count in full. Common ("weak") words add up, but on their own they can never
  /// reach the match threshold ("even if the mean value is odd" is not a statistics syllabus).
  static double _score(Map<String, double> hits, _Terms rule) {
    var strong = 0.0, weak = 0.0;
    hits.forEach((term, w) {
      if (w == 0.75 && rule.weak.contains(term)) {
        weak += w;
      } else {
        strong += w;
      }
    });
    return strong + (strong > 0 ? weak : (weak < matchThreshold ? weak : matchThreshold - 0.1));
  }

  static double _csBonus(String normalized, List<String> tokens) {
    var b = 0.0;
    for (final w in _csGeneral) {
      if (w.contains(' ') ? normalized.contains(' $w ') : tokens.any((t) => _tokenMatches(t, w))) b += 0.75;
    }
    return b;
  }

  // ------------------------------------------------------------------ topic extraction
  static final RegExp _bullet = RegExp(r'^\s*(?:[-*\u2022\u25CF\u25AA]|\d+[.)]|[a-z][.)])\s+');
  static final RegExp _label = RegExp(r'^\s*(course|unit\s*\d*|chapter\s*\d*|module\s*\d*|semester|subject|code)\s*[:\-]', caseSensitive: false);

  /// Splits notes into topics: bullet lines, "Topics:" lists, otherwise comma/semicolon/line separated fragments.
  static List<String> extractTopics(String input) {
    final out = <String>[];
    for (final rawLine in input.split(RegExp(r'[\r\n]+'))) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      final isBullet = _bullet.hasMatch(line);
      line = line.replaceFirst(_bullet, '').trim();
      if (_label.hasMatch(line) && !isBullet) continue; // "Course: ...", "Unit 2: ..." headings
      line = line.replaceFirst(RegExp(r'^(topics?|learning objectives?|objectives?|syllabus|contents?)\s*:\s*', caseSensitive: false), '').trim();
      if (line.isEmpty) continue;
      final parts = isBullet ? [line] : line.split(RegExp(r'[;,]|\.\s+')).map((p) => p.trim()).where((p) => p.length > 2);
      for (final p in parts) {
        final cleaned = p.replaceAll(RegExp(r'\.$'), '').trim();
        if (cleaned.length > 2 && !out.contains(cleaned)) out.add(cleaned);
      }
    }
    return out.take(60).toList();
  }

  // ------------------------------------------------------------------ main entry
  static TopicIntakeResult analyzeText(String input) {
    final text = _normalize(input);
    final tokens = _tokens(text);
    final all = ActivityRegistry.allActivities;

    // 1. score every practical against the whole text
    final scores = <String, double>{};
    final terms = <String, Map<String, double>>{};
    for (final a in all) {
      final rule = _rules[a.id];
      if (rule == null) continue;
      final hits = _hits(text, tokens, rule);
      var score = _score(hits, rule);
      if (a.subjectId == 'computer_science' && score > 0) score += _csBonus(text, tokens);
      scores[a.id] = score;
      terms[a.id] = hits;
    }
    // General programming words alone point at the coding practicals as a group.
    final csGeneral = _csBonus(text, tokens);
    if (csGeneral >= matchThreshold) {
      for (final a in all.where((a) => a.subjectId == 'computer_science')) {
        scores[a.id] = (scores[a.id] ?? 0) < csGeneral ? csGeneral : scores[a.id]!;
      }
    }

    final matchedActivities = all.where((a) => (scores[a.id] ?? 0) >= matchThreshold).toList()
      ..sort((x, y) => (scores[y.id] ?? 0).compareTo(scores[x.id] ?? 0));

    // 2. unsupported topics that were recognised
    final unsupported = <String>[];
    final relatedFallback = <String>{};
    for (final u in _unsupported) {
      final found = u.keywords.any((k) => k.contains(' ') ? text.contains(' $k ') : tokens.any((t) => _tokenMatches(t, k)));
      if (found) {
        unsupported.add(u.name);
        if (u.related != null) relatedFallback.add(u.related!);
      }
    }

    // 3. per-topic mapping
    final mappings = <TopicMapping>[];
    for (final topic in extractTopics(input)) {
      final tn = _normalize(topic);
      final tt = _tokens(tn);
      PracticalActivity? best;
      var bestScore = 0.0;
      var bestTerms = <String>[];
      for (final a in all) {
        final rule = _rules[a.id];
        if (rule == null) continue;
        final hits = _hits(tn, tt, rule);
        final sc = _score(hits, rule);
        if (sc > bestScore) {
          bestScore = sc;
          best = a;
          bestTerms = hits.keys.toList();
        }
      }
      if (best != null && bestScore >= matchThreshold) {
        mappings.add(TopicMapping(topic: topic, activity: best, matchedTerms: bestTerms));
      } else {
        mappings.add(TopicMapping(topic: topic));
      }
    }
    // Practicals found in single lines must also be recommended even if the whole-text score was split.
    for (final m in mappings) {
      if (m.activity != null && !matchedActivities.contains(m.activity)) matchedActivities.add(m.activity!);
    }

    final matched = matchedActivities.isNotEmpty;
    var recommended = matchedActivities;
    var guidanceSuffix = '';
    if (!matched && relatedFallback.isNotEmpty) {
      recommended = all.where((a) => relatedFallback.contains(a.id)).toList();
      guidanceSuffix = ' Closest foundation practical shown, because your topic itself has no practical yet.';
    }

    // 4. subjects
    final subjectScore = <String, double>{};
    for (final a in matchedActivities) {
      subjectScore[a.subjectId] = (subjectScore[a.subjectId] ?? 0) + (scores[a.id] ?? matchThreshold);
    }
    final subjectsRanked = subjectScore.entries.toList()..sort((x, y) => y.value.compareTo(x.value));
    PracticalSubject subjectById(String id) => PracticalSubject.defaultSubjects.firstWhere((s) => s.id == id, orElse: () => PracticalSubject.defaultSubjects.first);
    final matchedSubject = matched ? subjectById(subjectsRanked.first.key) : PracticalSubject.defaultSubjects.first;
    final others = [for (final e in subjectsRanked.skip(1)) subjectById(e.key)];

    if (!matched && recommended.isEmpty) recommended = List.of(all); // nothing fits: offer everything, clearly flagged

    final concepts = <String>[];
    for (final a in matchedActivities) {
      concepts.addAll(_concepts(a, terms[a.id] ?? const {}));
    }

    return TopicIntakeResult(
      queryText: input,
      matched: matched,
      matchedSubject: matchedSubject,
      otherSubjects: others,
      extractedKeyConcepts: concepts.toSet().toList(),
      recommendedActivities: recommended,
      topicMappings: mappings,
      unsupportedTopics: unsupported,
      pedagogicalGuidance: _guidance(input, matched, matchedActivities, mappings, unsupported) + guidanceSuffix,
      externalResources: [for (final a in recommended) if (a.externalLab != null) a.externalLab!],
    );
  }

  static List<String> _concepts(PracticalActivity a, Map<String, double> hits) {
    bool any(List<String> ks) => hits.keys.any((h) => ks.any((k) => h.contains(k)));
    switch (a.id) {
      case 'physics_ohms_law':
        return [
          "Ohm's Law: Current Proportionality (I = V/R)",
          if (any(['volt', 'potential', 'emf'])) 'Electromotive Force & Potential Difference',
          if (any(['resist', 'conductor'])) 'Ohmic Conductors & Resistance',
        ];
      case 'math_statistics_data':
        return [
          'Arithmetic Mean & Summation Measures',
          if (any(['median', 'outlier', 'skew'])) 'Median Resilience against Skewed Outliers',
          if (any(['variance', 'deviation', 'dispersion', 'distribution'])) 'Dispersion & Spread of Data',
        ];
      case 'chemistry_dilution':
        return [
          'Conservation of Solute in Dilution (C₁V₁ = C₂V₂)',
          if (any(['molar', 'concentration', 'normality'])) 'Molar Concentration (moles/Litre)',
          if (any(['titrat', 'acid'])) 'Neutralization & Titration Stoichiometry',
        ];
      case 'cs_sum_two_numbers':
        return ['Arithmetic Operations & Return Values'];
      case 'cs_even_or_odd':
        return ['Modulo Arithmetic & Parity Logic'];
      case 'cs_reverse_string':
        return ['String Indexing & Sequence Reversal'];
      case 'bio_osmosis':
        return ['Osmotic Pressure & Selective Permeability', 'Hypertonic, Isotonic, and Hypotonic Tonicity'];
    }
    return [a.conceptTested];
  }

  static String _guidance(String input, bool matched, List<PracticalActivity> acts, List<TopicMapping> maps, List<String> unsupported) {
    if (input.trim().isEmpty) return 'Type a topic or paste your syllabus to find practicals.';
    if (!matched) {
      return 'No PractiVerse practical matches this text yet. Showing everything available so you can browse. Try naming the concept directly, e.g. "Ohm\'s law", "median and outliers", "dilution", "even or odd".';
    }
    final covered = maps.where((m) => m.hasPractical).length;
    final names = acts.map((a) => a.title).join(', ');
    return 'Matched ${acts.length} practical${acts.length == 1 ? '' : 's'} ($names) by keyword'
        '${maps.isNotEmpty ? '; $covered of ${maps.length} topic lines in your text have a practical' : ''}.'
        '${unsupported.isNotEmpty ? ' Topics recognised without a practical yet: ${unsupported.join(', ')}.' : ''}';
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

class _Terms {
  final List<String> strong;
  final List<String> weak;
  final List<String> phrases;
  const _Terms({required this.strong, required this.weak, required this.phrases});
}

class _Unsupported {
  final String name;
  final List<String> keywords;
  final String? related;
  const _Unsupported(this.name, this.keywords, this.related);
}
