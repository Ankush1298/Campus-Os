import 'package:flutter/material.dart';

import '../models/topic_intake_result.dart';
import '../models/student_progress.dart';
import '../../auth/services/auth_service.dart';
import '../engine/practical_generator.dart';
import '../engine/topic_intake_engine.dart';
import '../models/generated_practical.dart';
import '../models/practical_activity.dart';
import 'activity_workspace_screen.dart';

class TopicIntakeScreen extends StatefulWidget {
  final StudentProgress progress;

  const TopicIntakeScreen({super.key, required this.progress});

  @override
  State<TopicIntakeScreen> createState() => _TopicIntakeScreenState();
}

class _TopicIntakeScreenState extends State<TopicIntakeScreen> {
  final TextEditingController _inputController = TextEditingController();
  TopicIntakeResult? _analysisResult;
  bool _isAnalyzing = false;
  bool _generating = false;
  String? _genMessage;
  bool _genFailed = false;
  List<GeneratedPractical> _saved = GeneratedPracticalStore.items;

  @override
  void initState() {
    super.initState();
    GeneratedPracticalStore.load().then((l) {
      if (mounted) setState(() => _saved = l);
    });
  }

  /// Generates a practical for ANY topic (AI on the server, or built from the pasted notes) and opens it.
  Future<void> _generate() async {
    final text = _inputController.text.trim();
    if (text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type a topic or paste your notes first.'),
        ),
      );
      return;
    }
    setState(() {
      _generating = true;
      _genMessage = null;
      _genFailed = false;
    });
    final res = await PracticalGenerator.generate(
      text,
      session: AuthService.instance.currentSession.value,
    );
    if (!mounted) return;
    setState(() {
      _generating = false;
      _genMessage = res.message;
      _genFailed = !res.ok;
    });
    final p = res.practical;
    if (p == null) return;
    GeneratedPracticalStore.save(p); // persisted in the background; the in-memory list is already updated
    if (!mounted) return;
    setState(() => _saved = GeneratedPracticalStore.items);
    _open(p);
  }

  void _open(GeneratedPractical p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityWorkspaceScreen(
          activity: p.toActivity(),
          progress: widget.progress,
        ),
      ),
    );
  }

  void _analyzeInput([String? presetText]) {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter syllabus text, topic title, or select a preset.',
          ),
        ),
      );
      return;
    }

    if (presetText != null) {
      _inputController.text = presetText;
    }

    setState(() {
      _isAnalyzing = true;
    });

    final result = TopicIntakeEngine.analyzeText(text);

    setState(() {
      _analysisResult = result;
      _isAnalyzing = false;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Topic & Syllabus Intake')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informational Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B1B3A), Color(0xFF0E7C86)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.travel_explore_rounded,
                        color: Colors.amberAccent,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Syllabus Mapping',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Paste a topic, chapter notes or your course syllabus. PractiVerse matches each topic to the practicals it has (keyword matching, not AI) and tells you which topics have no practical yet.',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Preset Syllabuses
            const Text(
              'Sample Syllabus Presets (1-Tap Load):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF46566F),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TopicIntakeEngine.sampleSyllabuses.entries.map((
                  entry,
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12),
                      ),
                      avatar: const Icon(
                        Icons.bookmark_added_rounded,
                        size: 16,
                      ),
                      onPressed: () => _analyzeInput(entry.value),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Input TextField
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Academic Material or Syllabus Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('practiverse-syllabus-input'),
                      controller: _inputController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Unit 2: DC Circuits, Ohm\'s Law, resistance in series and parallel, current drift velocity...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const Key('practiverse-generate-btn'),
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          _generating
                              ? 'Generating...'
                              : 'Generate a practical for this text',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Works for any topic or subject: theory first, then an interactive practical, and a quiz only if you miss it. Uses AI when the server is reachable (demo mode too); otherwise it builds a recall lesson from your pasted notes.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF46566F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('practiverse-analyze-btn'),
                        onPressed: _isAnalyzing || _generating
                            ? null
                            : () => _analyzeInput(),
                        icon: const Icon(Icons.manage_search_rounded),
                        label: const Text('Match existing practicals'),
                      ),
                    ),
                    if (_generating)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(),
                            SizedBox(height: 6),
                            Text(
                              'Writing your practical. This can take up to a minute.',
                              key: Key('gen-progress'),
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    if (_genMessage != null)
                      Container(
                        key: const Key('gen-message'),
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _genFailed
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _genMessage!,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: _genFailed
                                ? const Color(0xFF9E1C27)
                                : const Color(0xFF7A4B00),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (_saved.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Your generated practicals',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 6),
              for (final g in _saved)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: Key('saved-${g.id}'),
                    title: Text(
                      g.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${g.subject} • ${g.difficulty} • ${g.source == GeneratedSource.ai ? 'AI-generated' : 'from your notes'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                    onTap: () => _open(g),
                  ),
                ),
            ],

            // Analysis Result Presentation
            if (_analysisResult != null) ...[
              const SizedBox(height: 20),
              _buildAnalysisResultCard(context, _analysisResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResultCard(
    BuildContext context,
    TopicIntakeResult result,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!result.matched)
              Container(
                key: const Key('intake-no-match'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.search_off_rounded, color: Color(0xFF92400E)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No practical matches this text yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7A4B00),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: result.matchedSubject.accentColor
                        .withValues(alpha: 0.15),
                    child: Icon(
                      result.matchedSubject.icon,
                      color: result.matchedSubject.accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.matchedSubject.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          result.otherSubjects.isEmpty
                              ? 'Matched Academic Discipline'
                              : 'Also touches: ${result.otherSubjects.map((x) => x.name).join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF56667F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (!result.matched)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('intake-generate-from-nomatch'),
                    onPressed: _generating ? null : _generate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generate a practical for this text'),
                  ),
                ),
              ),
            if (result.topicMappings.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Topics found in your text:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF2C3C58),
                ),
              ),
              const SizedBox(height: 6),
              for (final m in result.topicMappings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        m.hasPractical
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 16,
                        color: m.hasPractical
                            ? const Color(0xFF0F9D6B)
                            : const Color(0xFF74839D),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: m.topic,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: m.hasPractical
                                    ? '  →  ${m.activity!.title}'
                                    : '  →  no practical yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: m.hasPractical
                                      ? const Color(0xFF0E7C86)
                                      : const Color(0xFF56667F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (result.unsupportedTopics.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Recognised, but no practical yet: ${result.unsupportedTopics.join(', ')}.',
                key: const Key('intake-unsupported'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A4B00)),
              ),
            ],
            if (result.extractedKeyConcepts.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Extracted Key Theoretical Concepts:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF2C3C58),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: result.extractedKeyConcepts.map((concept) {
                  return Chip(
                    label: Text(concept, style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                result.pedagogicalGuidance,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF46566F),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              result.matched
                  ? 'Recommended Interactive Practicals:'
                  : 'All available practicals:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            for (final activity in result.recommendedActivities)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      title: Text(
                        activity.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${activity.formulaNotation} • ${activity.difficulty}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF56667F),
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF0E7C86),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActivityWorkspaceScreen(
                              activity: activity,
                              progress: widget.progress,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
