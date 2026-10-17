import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../../auth/models/user_session.dart';
import '../models/generated_practical.dart';
import 'local_practical_builder.dart';

class PracticalGenResult {
  final GeneratedPractical? practical;

  /// Why the AI route was not used (shown to the student next to a notes-based fallback), or why nothing was produced.
  final String? message;
  const PracticalGenResult({this.practical, this.message});
  bool get ok => practical != null;
}

/// Asks the server for a NEW review quiz that avoids [asked]. Throws on any failure (the caller falls back to
/// a locally written quiz). Demo sessions use the restricted demo token, like generation.
Future<List<GeneratedQuiz>> fetchFreshQuiz({
  required UserSession? session,
  required String title,
  required String theory,
  required List<String> asked,
  Future<Map<String, dynamic>> Function(Map<String, dynamic> body, String? token)? post,
}) async {
  if (session == null) throw StateError('not signed in');
  Future<Map<String, dynamic>> send(Map<String, dynamic> body, String? token) =>
      ApiClient.post('/api/practiverse/quiz', body, erp: true, timeout: const Duration(seconds: 80), token: token);
  String? token;
  if (session.isDemo) {
    final res = await ApiClient.post('/api/auth/demo', {}, erp: true, timeout: const Duration(seconds: 30), token: '');
    token = res['token'] as String?;
  }
  final res = await (post ?? send)({'title': title, 'theory': theory, 'avoid': asked.take(30).toList()}, token);
  return [for (final q in (res['quiz'] as List)) ?GeneratedQuiz.tryParse(q)];
}

typedef RemoteGenerate = Future<Map<String, dynamic>> Function(String text);

/// Turns any topic or syllabus into a practical.
///  1. Signed-in (non-demo) users: the CampusOS server asks the language model (key stays on the server).
///     The reply is re-validated here (including the formula) before it is used.
///  2. If that is impossible (no server, no key, offline, limit), a practical is built from the pasted notes
///     locally. This is clearly labelled and needs real notes; a bare title cannot be expanded without the AI.
class PracticalGenerator {
  static Future<Map<String, dynamic>> _remote(String text, {String? token}) => ApiClient.post(
        '/api/practiverse/generate',
        {'text': text},
        erp: true,
        timeout: const Duration(seconds: 100),
        token: token,
      );

  /// Demo sessions have no account. The server hands out a 1-hour token that can ONLY generate practicals
  /// (it is refused by every other endpoint), so the demo buttons can still use the AI.
  static Future<String> _demoToken() async {
    final res = await ApiClient.post('/api/auth/demo', {}, erp: true, timeout: const Duration(seconds: 30), token: '');
    final t = res['token'];
    if (t is! String || t.isEmpty) throw const FormatException('no demo token');
    return t;
  }

  static Future<PracticalGenResult> generate(String text, {UserSession? session, RemoteGenerate? remote}) async {
    final input = text.trim();
    if (input.length < 3) return const PracticalGenResult(message: 'Enter a topic, chapter notes or a syllabus.');

    String? why;
    if (session == null) {
      why = 'You are not signed in, so AI generation is unavailable.';
    } else {
      try {
        final Map<String, dynamic> res;
        if (remote != null) {
          res = await remote(input);
        } else if (session.isDemo) {
          res = await _remote(input, token: await _demoToken());
        } else {
          res = await _remote(input);
        }
        final json = Map<String, dynamic>.from(res['practical'] as Map);
        final p = GeneratedPractical.fromJson(json, sourceText: input);
        return PracticalGenResult(practical: p);
      } on ApiException catch (e) {
        final code = (e.details is Map && (e.details as Map)['error'] is Map) ? ((e.details as Map)['error'] as Map)['code'] : null;
        if (e.statusCode == 429 || code == 'refused') {
          // A limit or a refusal is not something a local fallback should hide.
          return PracticalGenResult(message: e.message);
        }
        why = switch (code) {
          'llm_not_configured' => 'The server has no AI key configured (an administrator must set GROQ_API_KEY or ANTHROPIC_API_KEY).',
          'llm_busy' || 'llm_unreachable' => 'The AI service is busy or unreachable right now.',
          _ => e.statusCode == 0 ? 'Cannot reach the CampusOS server (${e.message}).' : e.message,
        };
      } on FormatException catch (e) {
        why = 'The AI answer could not be used (${e.message}).';
      } catch (e) {
        why = 'AI generation failed ($e).';
      }
    }

    final local = LocalPracticalBuilder.fromNotes(input);
    if (local != null) {
      return PracticalGenResult(practical: local, message: '$why Built a recall practical from your pasted notes instead (no AI).');
    }
    return PracticalGenResult(
      message: '$why To work without the AI, paste several sentences of notes (at least 4) so questions can be built from them.',
    );
  }
}

/// Keeps the last generated practicals on the device so they can be reopened.
class GeneratedPracticalStore {
  static const int maxItems = 20;
  static List<GeneratedPractical> _cache = [];

  static Future<File> _file() async {
    final dir = Platform.environment.containsKey('FLUTTER_TEST') ? Directory.systemTemp : await getApplicationSupportDirectory();
    return File('${dir.path}/campusos_generated_practicals.json');
  }

  static List<GeneratedPractical> get items => List.unmodifiable(_cache);

  static Future<List<GeneratedPractical>> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        _cache = [for (final j in list) ?_tryStored(Map<String, dynamic>.from(j as Map))];
      }
    } catch (_) {
      _cache = [];
    }
    return items;
  }

  static GeneratedPractical? _tryStored(Map<String, dynamic> j) {
    try {
      return GeneratedPractical.fromStored(j);
    } catch (_) {
      return null; // a corrupt entry is skipped, never crashes the screen
    }
  }

  /// Updates the in-memory list immediately and persists in the background: opening a practical never waits on disk.
  static Future<void> save(GeneratedPractical p) {
    _cache = [p, ..._cache.where((x) => x.id != p.id)].take(maxItems).toList();
    return _persist();
  }

  static Future<void> _persist() async {
    try {
      await (await _file()).writeAsString(jsonEncode([for (final x in _cache) x.toJson()]), flush: true);
    } catch (_) {}
  }

  /// Test helper: forget everything in memory (synchronously).
  static void resetCache() => _cache = [];
}
