import 'package:flutter/material.dart';

import '../models/topic_intake_result.dart';
import '../models/student_progress.dart';
import '../engine/topic_intake_engine.dart';
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
                        Icons.auto_awesome_rounded,
                        color: Colors.amberAccent,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AI-Assisted Syllabus Mapping',
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
                    'Paste your chapter notes, course syllabus, or academic topics. PractiVerse will extract core theoretical concepts and recommend interactive simulations and virtual lab experiments.',
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
                        key: const Key('practiverse-analyze-btn'),
                        onPressed: _isAnalyzing ? null : () => _analyzeInput(),
                        icon: const Icon(Icons.psychology_rounded),
                        label: const Text('Analyze & Discover Practicals'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B1B3A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: result.matchedSubject.accentColor.withValues(
                    alpha: 0.15,
                  ),
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
                      const Text(
                        'Matched Academic Discipline',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF56667F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            const Text(
              'Recommended Interactive Practicals:',
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
