import 'package:flutter/material.dart';

import '../models/practical_brief.dart';

/// Objective / Task / numbered Steps / Inputs / Expected result / Validation, same layout for every practical.
class PracticalBriefCard extends StatelessWidget {
  final PracticalBrief brief;
  const PracticalBriefCard({super.key, required this.brief});

  Widget _section(String title, Widget body) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: Color(0xFF56667F),
          ),
        ),
        const SizedBox(height: 3),
        body,
      ],
    ),
  );

  Widget _text(String t) => Text(
    t,
    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1B2B4B)),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('practical-brief'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 18,
                  color: Color(0xFF0E7C86),
                ),
                SizedBox(width: 8),
                Text(
                  'What you need to do',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section('Objective', _text(brief.objective)),
            _section('Your task', _text(brief.task)),
            _section(
              'Steps',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < brief.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(child: _text(brief.steps[i])),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _section('What you can change', _text(brief.inputs)),
            _section('Expected result', _text(brief.expected)),
            _section('How it is checked', _text(brief.validation)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: Color(0xFF46566F),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      brief.notice,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF46566F),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
