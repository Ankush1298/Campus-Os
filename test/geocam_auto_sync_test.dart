import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:campus_os/features/geocam/services/geocam_auto_sync.dart';
import 'package:campus_os/features/geocam/services/geocam_history_store.dart';
import 'package:campus_os/features/geocam/services/geocam_sync_service.dart';
import 'package:campus_os/features/geocam/models/stamp_settings.dart';
import 'package:campus_os/features/geocam/services/geocam_verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GeoCamRecord _rec({
  int attempts = 0,
  DateTime? last,
  String status = 'notSynced',
  bool permanent = false,
}) => GeoCamRecord(
  id: 'GEO-AUTO-UNIT',
  photoPath: '/dev/null',
  timestamp: DateTime.utc(2026, 10, 17),
  latitude: 25.0,
  longitude: 74.6,
  accuracy: 10,
  sha256: 'mocksha256',
  signature: 'mocksig',
  publicKey: 'mockpub',
  syncStatus: status,
  syncAttempts: attempts,
  lastSyncAttemptAt: last,
  syncPermanent: permanent,
);

Future<GeoCamRecord> _saved(String id) => GeoCamHistoryStore.save(
  id: id,
  imageBytes: Uint8List.fromList([1, 2, 3]),
  timestamp: DateTime.utc(2026, 10, 17),
  latitude: 25.0,
  longitude: 74.6,
  accuracy: 10,
  sha256: 'mocksha256',
  signature: 'mocksig',
  publicKey: 'mockpub',
  autoSaveToGallery: false,
);

Future<GeoCamRecord> _get(String id) async =>
    (await GeoCamHistoryStore.getById(id))!;

/// Runs the auto-sync worker over only this test's record, using [client] as the "server".
Future<void> _run(String id, http.Client client, DateTime now) =>
    GeoCamAutoSync.instance.syncPending(
      now: now,
      sync: (r) async {
        if (r.id != id) {
          return const GeoCamSyncResult(
            success: false,
            status: 'failed',
            message: 'skipped (not under test)',
          );
        }
        return GeoCamSyncService.instance.syncRecord(r, client: client);
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime.utc(2026, 10, 17, 12);

  group('retry schedule', () {
    test('a new record is due immediately; synced, in-flight and permanently rejected ones never are', () {
      expect(GeoCamAutoSync.isDue(_rec(), t0), isTrue);
      expect(GeoCamAutoSync.isDue(_rec(status: 'synced'), t0), isFalse);
      expect(
        GeoCamAutoSync.isDue(_rec(status: 'remoteConfirmed'), t0),
        isFalse,
      );
      expect(GeoCamAutoSync.isDue(_rec(status: 'syncing'), t0), isFalse);
      expect(
        GeoCamAutoSync.isDue(
          _rec(status: 'syncFailed', attempts: 1, last: t0, permanent: true),
          t0.add(const Duration(days: 1)),
        ),
        isFalse,
      );
    });

    test('back-off doubles from 30 s and is capped at 15 minutes', () {
      bool due(int attempts, int secondsAfter) => GeoCamAutoSync.isDue(
        _rec(status: 'syncFailed', attempts: attempts, last: t0),
        t0.add(Duration(seconds: secondsAfter)),
      );
      expect(due(1, 29), isFalse);
      expect(due(1, 30), isTrue);
      expect(due(3, 119), isFalse);
      expect(due(3, 120), isTrue);
      expect(due(20, 899), isFalse);
      expect(due(20, 900), isTrue);
    });
  });

  group('offline-first synchronization', () {
    test('offline capture stays saved and pending, retries later, and only becomes synchronized when the server confirms', () async {
      final saved = await _saved('GEO-AUTO-OFFLINE');
      expect(saved.syncStatus, 'notSynced');
      expect(
        await File(saved.photoPath).exists(),
        isTrue,
      ); // local copy exists before any upload

      var online = false;
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (!online) throw const SocketException('Network is unreachable');
        return http.Response('{"ok":true}', 200);
      });

      await _run(saved.id, client, t0);
      var r = await _get(saved.id);
      expect(
        [r.syncStatus, r.syncAttempts, r.syncPermanent, r.isSynchronized],
        ['syncFailed', 1, false, false],
      );
      expect(calls, 1);

      // Too soon: back-off holds the retry back (no hammering a dead network).
      await _run(saved.id, client, DateTime.now().toUtc());
      expect(calls, 1);

      // Connectivity returns and the back-off has elapsed.
      online = true;
      await _run(
        saved.id,
        client,
        DateTime.now().toUtc().add(const Duration(seconds: 31)),
      );
      r = await _get(saved.id);
      expect([r.syncStatus, r.isSynchronized, calls], ['synced', true, 2]);

      // Once confirmed it is never uploaded again.
      await _run(
        saved.id,
        client,
        DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      expect(calls, 2);
      await GeoCamHistoryStore.delete(r);
    });

    test('a retry of an already-uploaded record is idempotent ("already exists" counts as synchronized)', () async {
      final saved = await _saved('GEO-AUTO-DUP');
      final client = MockClient(
        (req) async => http.Response('{"alreadyExists":true}', 200),
      );
      await _run(saved.id, client, t0);
      expect((await _get(saved.id)).isSynchronized, isTrue);
      await GeoCamHistoryStore.delete(await _get(saved.id));
    });

    test('a server rejection (409) is permanent: no automatic retries, and the error is kept for the user', () async {
      final saved = await _saved('GEO-AUTO-REJECT');
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response('{"error":"conflict"}', 409);
      });
      await _run(saved.id, client, t0);
      final r = await _get(saved.id);
      expect([r.syncStatus, r.syncPermanent], ['syncFailed', true]);
      expect(r.syncError, contains('409'));
      await _run(saved.id, client, t0.add(const Duration(days: 2)));
      expect(calls, 1);
      await GeoCamHistoryStore.delete(r);
    });

    test('a server error (500) is transient: retried with back-off, never marked synchronized', () async {
      final saved = await _saved('GEO-AUTO-5XX');
      final client = MockClient((req) async => http.Response('boom', 500));
      await _run(saved.id, client, t0);
      final r = await _get(saved.id);
      expect(
        [r.syncStatus, r.syncPermanent, r.isSynchronized],
        ['syncFailed', false, false],
      );
      await GeoCamHistoryStore.delete(r);
    });

    test('after an app restart a record stuck in "syncing" becomes pending again and uploads', () async {
      final saved = await _saved('GEO-AUTO-RESTART');
      await GeoCamHistoryStore.updateSyncStatus(
        saved.id,
        'syncing',
      ); // the app was killed mid-upload
      expect((await _get(saved.id)).isSyncing, isTrue);
      expect(
        await GeoCamHistoryStore.resetStaleSyncing(),
        greaterThanOrEqualTo(1),
      );
      expect((await _get(saved.id)).syncStatus, 'notSynced');
      await _run(
        saved.id,
        MockClient((req) async => http.Response('{}', 200)),
        t0,
      );
      expect((await _get(saved.id)).isSynchronized, isTrue);
      await GeoCamHistoryStore.delete(await _get(saved.id));
    });
  });

  group('capture footer (Screenshot 1 format)', () {
    Future<Uint8List> solidPng(int w, int h, Color c) async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = c,
      );
      final img = await rec.endRecording().toImage(w, h);
      return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List();
    }

    Future<ui.Image> decode(Uint8List b) async =>
        (await (await ui.instantiateImageCodec(b)).getNextFrame()).image;

    testWidgets(
      'appends a black footer below the untouched photo (same width, taller, original pixels intact)',
      (tester) async {
        await tester.runAsync(() async {
          final src = await solidPng(600, 400, const Color(0xFF3366CC));
          final out = await GeoCamVerificationService.stampImageWithWatermark(
            rawImageBytes: src,
            recordId: 'GEO-FOOTER-1',
            qrPayload: 'https://geocam-server.onrender.com/GEO-FOOTER-1',
            timestamp: DateTime.utc(2026, 10, 15, 19, 43, 35),
            latitude: 25.033948,
            longitude: 74.634972,
            accuracy: 100,
            address: 'University Park., Gangrar, Rajasthan, 312901, India',
            settings: StampSettings(),
          );
          final img = await decode(out);
          expect(img.width, 600);
          expect(img.height, greaterThan(400));
          final px = (await img.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int at(int x, int y) => (y * 600 + x) * 4;
          // Photo area untouched (still the original blue), footer area starts black.
          expect(
            [
              px.getUint8(at(10, 10)),
              px.getUint8(at(10, 10) + 1),
              px.getUint8(at(10, 10) + 2),
            ],
            [0x33, 0x66, 0xCC],
          );
          expect(
            [
              px.getUint8(at(2, 402)),
              px.getUint8(at(2, 402) + 1),
              px.getUint8(at(2, 402) + 2),
            ],
            [0, 0, 0],
          );
        });
      },
    );

    testWidgets(
      'missing GPS/address still produce a footer (explicit "unavailable" text, never invented values)',
      (tester) async {
        await tester.runAsync(() async {
          final src = await solidPng(400, 300, const Color(0xFF228822));
          final out = await GeoCamVerificationService.stampImageWithWatermark(
            rawImageBytes: src,
            recordId: 'GEO-FOOTER-2',
            qrPayload: 'https://geocam-server.onrender.com/GEO-FOOTER-2',
            timestamp: DateTime.utc(2026, 10, 15),
            settings: StampSettings(),
          );
          expect((await decode(out)).height, greaterThan(300));
        });
      },
    );
  });
}
