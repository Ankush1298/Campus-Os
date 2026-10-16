import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/practical_activity.dart';
import '../engine/activity_registry.dart';

class VirtualLabsDirectoryScreen extends StatelessWidget {
  const VirtualLabsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<ExternalLabResource> labs = ActivityRegistry.allActivities
        .where((a) => a.externalLab != null)
        .map((a) => a.externalLab!)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Virtual Labs & External Resources')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: labs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final lab = labs[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(
                          Icons.language_rounded,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lab.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              lab.provider,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lab.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lab.url,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy URL',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: lab.url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Virtual Lab URL copied to clipboard!',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
