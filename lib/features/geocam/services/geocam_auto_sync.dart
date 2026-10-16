import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'geocam_history_store.dart';
import 'geocam_sync_service.dart';

/// Uploads GeoCam captures in the background.
///
/// A capture is always saved locally first. This worker then uploads every record that is pending or
/// failed-but-retryable, one at a time, with exponential back-off (30 s, 60 s, ... capped at 15 min).
/// Uploads are idempotent on the server (same record id => "already exists"), so retries and
/// app restarts never create duplicate verification records. A record becomes "synchronized" only after
/// the server confirms it. Permanently rejected records are left for the user to inspect/retry by hand.
class GeoCamAutoSync with WidgetsBindingObserver {
  static final GeoCamAutoSync instance = GeoCamAutoSync._();
  GeoCamAutoSync._();

  static const Duration pollInterval = Duration(seconds: 30);
  static const int baseBackoffSeconds = 30;
  static const int maxBackoffSeconds = 900;

  /// Bumps after every attempt so screens can refresh.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Timer? _timer;
  bool _running = false;
  bool _started = false;

  /// Starts the periodic retry loop (idempotent). No-op under flutter_test.
  Future<void> start() async {
    if (_started || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    await GeoCamHistoryStore.resetStaleSyncing();
    _timer = Timer.periodic(pollInterval, (_) => syncPending());
    unawaited(syncPending());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncPending());
  }

  /// Whether [r] should be uploaded automatically at [now].
  static bool isDue(GeoCamRecord r, DateTime now) {
    if (r.isSynchronized || r.isSyncing || r.syncPermanent) return false;
    if (r.syncAttempts == 0 || r.lastSyncAttemptAt == null) return true;
    final wait = min(
      baseBackoffSeconds * pow(2, r.syncAttempts - 1).toInt(),
      maxBackoffSeconds,
    );
    return now.difference(r.lastSyncAttemptAt!).inSeconds >= wait;
  }

  /// Uploads every due record; returns how many were confirmed by the server.
  /// [now] and [sync] are injectable for tests.
  Future<int> syncPending({
    DateTime? now,
    Future<GeoCamSyncResult> Function(GeoCamRecord)? sync,
  }) async {
    if (_running) return 0;
    _running = true;
    var confirmed = 0;
    try {
      final upload = sync ?? GeoCamSyncService.instance.syncRecord;
      for (final r in await GeoCamHistoryStore.load()) {
        if (!isDue(r, now ?? DateTime.now())) continue;
        final res = await upload(r);
        if (res.success) confirmed++;
        changes.value++;
      }
    } finally {
      _running = false;
    }
    return confirmed;
  }

  /// Called right after a capture is saved. Never blocks or throws into the capture flow.
  Future<void> syncSoon() async {
    try {
      await syncPending();
    } catch (_) {}
  }
}
