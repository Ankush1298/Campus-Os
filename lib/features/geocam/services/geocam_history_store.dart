import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class GeoCamRecord {
  final String id;
  final String photoPath;
  final String qrPayload;
  final String mediaType;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? altitude;
  final String address;
  final String sha256;
  final String signature;
  final String publicKey;
  final String status;
  final String syncStatus; // 'notSynced', 'syncing', 'synced', 'syncFailed', 'remoteConfirmed'
  final DateTime? syncedAt;
  final String? syncError;
  final bool isSavedToGallery;
  final String? galleryError;
  // Automatic-sync bookkeeping (persisted so retries survive app restarts).
  final int syncAttempts;
  final DateTime? lastSyncAttemptAt;
  final bool syncPermanent; // server rejected it (or file is gone): do not retry automatically

  const GeoCamRecord({
    required this.id,
    required this.photoPath,
    String? qrPayload,
    this.mediaType = 'photo',
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.address = '',
    required this.sha256,
    this.signature = '',
    this.publicKey = '',
    this.status = 'VERIFIED',
    this.syncStatus = 'notSynced',
    this.syncedAt,
    this.syncError,
    this.isSavedToGallery = false,
    this.galleryError,
    this.syncAttempts = 0,
    this.lastSyncAttemptAt,
    this.syncPermanent = false,
  }) : qrPayload = qrPayload ?? 'https://geocam-server.onrender.com/$id';

  bool get hasCryptographicProof =>
      signature.isNotEmpty && sha256.isNotEmpty && publicKey.isNotEmpty;

  bool get isSynchronized =>
      syncStatus == 'synced' || syncStatus == 'remoteConfirmed';
  bool get isRemoteConfirmed => syncStatus == 'remoteConfirmed';
  bool get isSyncFailed => syncStatus == 'syncFailed';
  bool get isNotSynced => syncStatus == 'notSynced';
  bool get isSyncing => syncStatus == 'syncing';

  String get formattedCoordinates {
    if (latitude == null || longitude == null) {
      return 'GPS Location Unavailable';
    }
    final latDir = latitude! >= 0 ? 'N' : 'S';
    final lngDir = longitude! >= 0 ? 'E' : 'W';
    return '${latitude!.abs().toStringAsFixed(4)}° $latDir, ${longitude!.abs().toStringAsFixed(4)}° $lngDir';
  }

  GeoCamRecord copyWith({
    String? id,
    String? photoPath,
    String? qrPayload,
    String? mediaType,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    String? address,
    String? sha256,
    String? signature,
    String? publicKey,
    String? status,
    String? syncStatus,
    DateTime? syncedAt,
    String? syncError,
    bool? isSavedToGallery,
    String? galleryError,
    int? syncAttempts,
    DateTime? lastSyncAttemptAt,
    bool? syncPermanent,
  }) {
    return GeoCamRecord(
      id: id ?? this.id,
      photoPath: photoPath ?? this.photoPath,
      qrPayload: qrPayload ?? this.qrPayload,
      mediaType: mediaType ?? this.mediaType,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      address: address ?? this.address,
      sha256: sha256 ?? this.sha256,
      signature: signature ?? this.signature,
      publicKey: publicKey ?? this.publicKey,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: syncedAt ?? this.syncedAt,
      syncError: syncError ?? this.syncError,
      isSavedToGallery: isSavedToGallery ?? this.isSavedToGallery,
      galleryError: galleryError ?? this.galleryError,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      syncPermanent: syncPermanent ?? this.syncPermanent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'photoPath': photoPath,
    'qrPayload': qrPayload,
    'mediaType': mediaType,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'address': address,
    'sha256': sha256,
    'signature': signature,
    'publicKey': publicKey,
    'status': status,
    'syncStatus': syncStatus,
    'syncedAt': syncedAt?.toUtc().toIso8601String(),
    'syncError': syncError,
    'isSavedToGallery': isSavedToGallery,
    'galleryError': galleryError,
    'syncAttempts': syncAttempts,
    'lastSyncAttemptAt': lastSyncAttemptAt?.toUtc().toIso8601String(),
    'syncPermanent': syncPermanent,
  };

  factory GeoCamRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return GeoCamRecord(
      id: id,
      photoPath: json['photoPath'] as String,
      qrPayload:
          (json['qrPayload'] as String?) ??
          'https://geocam-server.onrender.com/$id',
      mediaType: (json['mediaType'] as String?) ?? 'photo',
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      address: (json['address'] as String?) ?? '',
      sha256:
          (json['sha256'] as String?) ?? (json['mediaSha256'] as String?) ?? '',
      signature: (json['signature'] as String?) ?? '',
      publicKey: (json['publicKey'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'VERIFIED',
      syncStatus: (json['syncStatus'] as String?) ?? 'notSynced',
      syncedAt: json['syncedAt'] != null
          ? DateTime.tryParse(json['syncedAt'] as String)
          : null,
      syncError: json['syncError'] as String?,
      isSavedToGallery: (json['isSavedToGallery'] as bool?) ?? false,
      galleryError: json['galleryError'] as String?,
      syncAttempts: (json['syncAttempts'] as int?) ?? 0,
      lastSyncAttemptAt: json['lastSyncAttemptAt'] != null
          ? DateTime.tryParse(json['lastSyncAttemptAt'] as String)
          : null,
      syncPermanent: (json['syncPermanent'] as bool?) ?? false,
    );
  }
}

class GeoCamHistoryStore {
  static Future<Directory> _rootDir() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      final dir = Directory('${Directory.systemTemp.path}/geocam_test_records');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/geocam_records');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _indexFile() async {
    final dir = await _rootDir();
    return File('${dir.path}/records.json');
  }

  static Future<List<GeoCamRecord>> load() async {
    if (kIsWeb) return <GeoCamRecord>[];
    try {
      final file = await _indexFile();
      if (!await file.exists()) return <GeoCamRecord>[];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return <GeoCamRecord>[];
      final records = <GeoCamRecord>[];
      for (final item in decoded.whereType<Map>()) {
        try {
          final record = GeoCamRecord.fromJson(Map<String, dynamic>.from(item));
          if (await File(record.photoPath).exists()) {
            records.add(record);
          }
        } catch (_) {}
      }
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    } catch (_) {
      return <GeoCamRecord>[];
    }
  }

  static Future<GeoCamRecord?> getById(String recordId) async {
    final records = await load();
    for (final r in records) {
      if (r.id == recordId) return r;
    }
    return null;
  }

  static Future<GeoCamRecord> save({
    required String id,
    required Uint8List imageBytes,
    String? qrPayload,
    required DateTime timestamp,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    double? altitude,
    String address = '',
    required String sha256,
    String signature = '',
    String publicKey = '',
    bool autoSaveToGallery = true,
  }) async {
    final dir = await _rootDir();
    final photoPath = '${dir.path}/$id.jpg';
    await File(photoPath).writeAsBytes(imageBytes, flush: true);

    final payload = (qrPayload != null && qrPayload.isNotEmpty)
        ? qrPayload
        : 'https://geocam-server.onrender.com/$id';

    var record = GeoCamRecord(
      id: id,
      photoPath: photoPath,
      qrPayload: payload,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      address: address,
      sha256: sha256,
      signature: signature,
      publicKey: publicKey,
    );

    final current = await load();
    current.removeWhere((r) => r.id == id);
    current.insert(0, record);

    final index = await _indexFile();
    await index.writeAsString(
      jsonEncode(current.map((r) => r.toJson()).toList()),
      flush: true,
    );

    if (autoSaveToGallery) {
      try {
        await saveToGallery(record);
        record = (await getById(id)) ?? record;
      } catch (_) {}
    }

    return record;
  }

  static Future<GeoCamRecord> saveVideo({
    required String id,
    required String videoPath,
    String? qrPayload,
    required DateTime timestamp,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    double? altitude,
    String address = '',
    required String sha256,
    String signature = '',
    String publicKey = '',
    bool autoSaveToGallery = true,
  }) async {
    final dir = await _rootDir();
    final targetPath = '${dir.path}/$id.mp4';
    await File(videoPath).copy(targetPath);

    final payload = (qrPayload != null && qrPayload.isNotEmpty)
        ? qrPayload
        : 'https://geocam-server.onrender.com/$id';

    var record = GeoCamRecord(
      id: id,
      photoPath: targetPath,
      qrPayload: payload,
      mediaType: 'video',
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      address: address,
      sha256: sha256,
      signature: signature,
      publicKey: publicKey,
    );

    final current = await load();
    current.removeWhere((r) => r.id == id);
    current.insert(0, record);

    final index = await _indexFile();
    await index.writeAsString(
      jsonEncode(current.map((r) => r.toJson()).toList()),
      flush: true,
    );

    if (autoSaveToGallery) {
      try {
        await saveToGallery(record);
        record = (await getById(id)) ?? record;
      } catch (_) {}
    }

    return record;
  }

  /// Automatically saves the finalized media file into the phone's public MediaStore/Photos gallery.
  /// Uses album 'CampusOS GeoCam' and avoids duplicate entries if already saved.
  static Future<bool> saveToGallery(GeoCamRecord record) async {
    if (record.isSavedToGallery) return true;
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        await updateGalleryStatus(record.id, true);
        return true;
      }
      final file = File(record.photoPath);
      if (!await file.exists()) {
        await updateGalleryStatus(
          record.id,
          false,
          galleryError: 'Local media file does not exist',
        );
        return false;
      }
      if (record.mediaType == 'video') {
        await Gal.putVideo(record.photoPath, album: 'CampusOS GeoCam');
      } else {
        await Gal.putImage(record.photoPath, album: 'CampusOS GeoCam');
      }
      await updateGalleryStatus(record.id, true);
      return true;
    } catch (e) {
      await updateGalleryStatus(record.id, false, galleryError: e.toString());
      return false;
    }
  }

  static Future<GeoCamRecord?> updateGalleryStatus(
    String id,
    bool isSaved, {
    String? galleryError,
  }) async {
    final current = await load();
    final index = current.indexWhere((r) => r.id == id);
    if (index == -1) return null;
    final old = current[index];
    final updated = old.copyWith(
      isSavedToGallery: isSaved,
      galleryError: galleryError,
    );
    current[index] = updated;
    final indexFile = await _indexFile();
    await indexFile.writeAsString(
      jsonEncode(current.map((r) => r.toJson()).toList()),
      flush: true,
    );
    return updated;
  }

  static Future<void> delete(GeoCamRecord record) async {
    try {
      final file = File(record.photoPath);
      if (await file.exists()) {
        await file.delete();
      }
      final current = await load();
      current.removeWhere((r) => r.id == record.id);
      final index = await _indexFile();
      await index.writeAsString(
        jsonEncode(current.map((r) => r.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }

  static Future<String> exportToGalleryOrDownloads(GeoCamRecord record) async {
    final source = File(record.photoPath);
    if (!await source.exists()) {
      throw Exception('Source media file does not exist');
    }
    final bytes = await source.readAsBytes();

    // Export to Android public Download directory (/storage/emulated/0/Download)
    // or system downloads/documents directory for universal compatibility
    Directory? exportDir;
    if (!kIsWeb && Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      final moviesDir = Directory('/storage/emulated/0/Movies');
      final targetCandidate =
          (record.mediaType == 'video' && moviesDir.existsSync())
          ? moviesDir
          : publicDownload;
      if (await targetCandidate.exists()) {
        exportDir = targetCandidate;
      }
    }

    if (exportDir == null) {
      try {
        exportDir = await getDownloadsDirectory();
      } catch (_) {}
    }
    exportDir ??= await getApplicationDocumentsDirectory();

    final ext = record.mediaType == 'video' ? 'mp4' : 'jpg';
    final exportPath = '${exportDir.path}/${record.id}.$ext';
    final target = File(exportPath);
    await target.writeAsBytes(bytes, flush: true);
    return exportPath;
  }

  static Future<GeoCamRecord?> updateSyncStatus(
    String id,
    String status, {
    DateTime? syncedAt,
    String? syncError,
  }) async {
    final current = await load();
    final index = current.indexWhere((r) => r.id == id);
    if (index == -1) return null;
    final old = current[index];
    final updated = old.copyWith(
      syncStatus: status,
      syncedAt:
          syncedAt ??
          (status == 'synced'
              ? (old.syncedAt ?? DateTime.now().toUtc())
              : old.syncedAt),
      syncError: syncError,
    );
    current[index] = updated;
    final indexFile = await _indexFile();
    await indexFile.writeAsString(
      jsonEncode(current.map((r) => r.toJson()).toList()),
      flush: true,
    );
    return updated;
  }

  static Future<void> _writeAll(List<GeoCamRecord> records) async {
    final indexFile = await _indexFile();
    await indexFile.writeAsString(
      jsonEncode(records.map((r) => r.toJson()).toList()),
      flush: true,
    );
  }

  /// Counts a failed upload attempt (drives the retry back-off). [permanent] stops automatic retries.
  static Future<void> recordSyncFailure(
    String id, {
    required bool permanent,
  }) async {
    final current = await load();
    final i = current.indexWhere((r) => r.id == id);
    if (i == -1) return;
    current[i] = current[i].copyWith(
      syncAttempts: current[i].syncAttempts + 1,
      lastSyncAttemptAt: DateTime.now().toUtc(),
      syncPermanent: permanent,
    );
    await _writeAll(current);
  }

  /// After a restart nothing can still be uploading, so a stored 'syncing' state is stale: make it pending again.
  static Future<int> resetStaleSyncing() async {
    final current = await load();
    var n = 0;
    for (var i = 0; i < current.length; i++) {
      if (current[i].syncStatus == 'syncing') {
        current[i] = current[i].copyWith(syncStatus: 'notSynced');
        n++;
      }
    }
    if (n > 0) await _writeAll(current);
    return n;
  }
}
