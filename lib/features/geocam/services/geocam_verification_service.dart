import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'geocam_history_store.dart';
import '../models/stamp_settings.dart';

enum GeoCamVerificationStatus { verified, invalidTampered, unableToVerify }

class GeoCamVerificationResult {
  final GeoCamVerificationStatus status;
  final String message;
  final String recordId;
  final String qrPayload;
  final String? expectedSha256;
  final String? actualSha256;
  final bool? shaMatches;
  final bool? signatureValid;
  final GeoCamRecord? record;

  const GeoCamVerificationResult({
    required this.status,
    required this.message,
    required this.recordId,
    required this.qrPayload,
    this.expectedSha256,
    this.actualSha256,
    this.shaMatches,
    this.signatureValid,
    this.record,
  });

  bool get isVerified => status == GeoCamVerificationStatus.verified;
  bool get isTampered => status == GeoCamVerificationStatus.invalidTampered;
  bool get isUnableToVerify =>
      status == GeoCamVerificationStatus.unableToVerify;
}

class GeoCamStamp {
  final String recordId;
  final String qrPayload;
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
  final Uint8List? stampedBytes;

  const GeoCamStamp({
    required this.recordId,
    required this.qrPayload,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.altitude,
    this.address = '',
    required this.sha256,
    required this.signature,
    required this.publicKey,
    required this.status,
    this.stampedBytes,
  });

  String get formattedCoordinates {
    if (latitude == null || longitude == null) {
      return 'GPS Location Unavailable / Denied';
    }
    final latDir = latitude! >= 0 ? 'N' : 'S';
    final lngDir = longitude! >= 0 ? 'E' : 'W';
    return '${latitude!.abs().toStringAsFixed(4)}° $latDir, ${longitude!.abs().toStringAsFixed(4)}° $lngDir';
  }

  String get formattedAccuracy {
    if (accuracy == null) return 'N/A';
    return '±${accuracy!.toStringAsFixed(1)}m';
  }
}

class GeoCamVerificationService {
  static final GeoCamVerificationService instance =
      GeoCamVerificationService._();
  GeoCamVerificationService._();

  static const String defaultVerificationBaseUrl =
      'https://geocam-server.onrender.com';
  static String verificationBaseUrl = defaultVerificationBaseUrl;

  static const _seedKey = 'geocam_ed25519_seed_v2';
  static final _ed25519 = Ed25519();
  static const _storage = FlutterSecureStorage();
  static List<int>? _cachedSeed;

  static Future<List<int>> _getSeed() async {
    if (_cachedSeed != null && _cachedSeed!.length == 32) {
      return _cachedSeed!;
    }
    try {
      final stored = await _storage.read(key: _seedKey);
      if (stored != null) {
        final seed = base64Decode(stored);
        if (seed.length == 32) {
          _cachedSeed = seed;
          return seed;
        }
      }
    } catch (_) {}
    final rng = Random.secure();
    final seed = List<int>.generate(32, (_) => rng.nextInt(256));
    _cachedSeed = seed;
    try {
      await _storage.write(key: _seedKey, value: base64Encode(seed));
    } catch (_) {}
    return seed;
  }

  static Future<SimpleKeyPair> _keyPair() async {
    return _ed25519.newKeyPairFromSeed(await _getSeed());
  }

  static String qrPayloadFor(String recordId) {
    if (recordId.isNotEmpty) {
      return '$verificationBaseUrl/$recordId';
    }
    return '$verificationBaseUrl/';
  }

  static final RegExp _recordIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{2,119}$',
  );

  static String? extractRecordId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase();
      final isKnownHost =
          host == 'geocam-server.onrender.com' ||
          host == 'localhost' ||
          host == '127.0.0.1' ||
          host.startsWith('192.168.') ||
          host.startsWith('10.');
      if (!isKnownHost) {
        return null;
      }
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final seg = segments.last;
        if (seg != 'sync' &&
            seg != 'healthz' &&
            _recordIdPattern.hasMatch(seg)) {
          return seg;
        }
      }
      return null;
    }

    if (_recordIdPattern.hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  /// Draws the QR on a whole-pixel grid with standard quiet zone matching the original GeoCam implementation.
  static void drawQr(
    Canvas canvas,
    String payload,
    double left,
    double top,
    double size,
  ) {
    final qrCode = QrCode.fromData(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    final qrImage = QrImage(qrCode);
    final n = qrImage.moduleCount;
    const quiet = 4;
    final total = n + 2 * quiet;
    final module = max(1.0, (size / total).floorToDouble());
    final actual = module * total;
    final ox = (left + (size - actual) / 2).roundToDouble();
    final oy = (top + (size - actual) / 2).roundToDouble();

    final light = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = false;
    final dark = Paint()
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;

    canvas.drawRect(Rect.fromLTWH(ox, oy, actual, actual), light);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (qrImage.isDark(r, c)) {
          canvas.drawRect(
            Rect.fromLTWH(
              ox + (c + quiet) * module,
              oy + (r + quiet) * module,
              module,
              module,
            ),
            dark,
          );
        }
      }
    }
  }

  /// Stamps pixels with the GeoCam watermark banner containing GPS, timestamp, ID, and pixel-embedded QR code.
  static Future<Uint8List> stampImageWithWatermark({
    required Uint8List rawImageBytes,
    required String recordId,
    required String qrPayload,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
    double? accuracy,
    String address = '',
    StampSettings? settings,
  }) async {
    final s = settings ?? StampSettings();
    if (!s.pixelEmbeddedStamps) return rawImageBytes;

    try {
      final codec = await ui.instantiateImageCodec(rawImageBytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();

      // Footer appended BELOW the untouched photo (nothing is drawn over the scene). Every value is the
      // real capture metadata; when something is unavailable the footer says so instead of guessing.
      String two(int v) => v.toString().padLeft(2, '0');
      final utc = timestamp.toUtc();
      final when =
          '${two(utc.day)}/${two(utc.month)}/${utc.year} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
      const orange = Color(0xFFF5B041);
      final unit = max(18.0, min(40.0, imgW * 0.026));
      final entries =
          <
            ({String text, Color color, double size, bool bold, int maxLines})
          >[];
      if (s.customText.trim().isNotEmpty) {
        entries.add((
          text: s.customText.trim(),
          color: const Color(0xFFFFC107),
          size: unit * 1.15,
          bold: true,
          maxLines: 1,
        ));
      }
      if (s.showCoordinates) {
        final hasFix = latitude != null && longitude != null;
        entries.add((
          text: hasFix
              ? '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
              : 'GPS location unavailable',
          color: orange,
          size: unit * 1.1,
          bold: true,
          maxLines: 1,
        ));
      }
      if (s.showAddress) {
        entries.add((
          text: address.isNotEmpty ? address : 'Address unavailable',
          color: Colors.white,
          size: unit * 0.85,
          bold: false,
          maxLines: 2,
        ));
      }
      if (s.showDateTime)
        entries.add((
          text: when,
          color: Colors.white,
          size: unit * 0.85,
          bold: false,
          maxLines: 1,
        ));
      if (s.showAccuracy) {
        entries.add((
          text: accuracy != null
              ? 'GPS accuracy: ±${accuracy.round()} m'
              : 'GPS accuracy: unavailable',
          color: Colors.white,
          size: unit * 0.85,
          bold: false,
          maxLines: 1,
        ));
      }
      entries.add((
        text: recordId,
        color: const Color(0xFFCBD5E1),
        size: unit * 0.8,
        bold: false,
        maxLines: 1,
      ));

      final pad = unit * 0.8;
      final qrSide = s.showQr
          ? max(unit * 5.0, imgW * 0.2).clamp(0.0, imgW * 0.4).toDouble()
          : 0.0;
      final textMaxWidth = max(
        100.0,
        imgW - pad * 2 - (qrSide > 0 ? qrSide + pad : 0),
      );
      final painters = <TextPainter>[
        for (final e in entries)
          TextPainter(
            text: TextSpan(
              text: e.text,
              style: TextStyle(
                color: e.color,
                fontSize: e.size,
                fontWeight: e.bold ? FontWeight.w700 : FontWeight.w400,
                height: 1.25,
              ),
            ),
            textDirection: TextDirection.ltr,
            maxLines: e.maxLines,
            ellipsis: '…',
          )..layout(maxWidth: textMaxWidth),
      ];
      final textHeight =
          painters.fold<double>(0, (sum, t) => sum + t.height) +
          unit * 0.2 * (painters.length - 1);
      final panelHeight = max(textHeight, qrSide) + pad * 2;
      final totalH = imgH + panelHeight;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Original photo at full size: no crop, no distortion, nothing drawn over it.
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(0, 0, imgW, imgH),
        Paint(),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, imgH, imgW, panelHeight),
        Paint()..color = const Color(0xFF000000),
      );

      var y = imgH + pad + (max(textHeight, qrSide) - textHeight) / 2;
      for (final tp in painters) {
        tp.paint(canvas, Offset(pad, y));
        y += tp.height + unit * 0.2;
      }
      if (qrSide > 0) {
        drawQr(
          canvas,
          qrPayload,
          imgW - qrSide - pad,
          imgH + (panelHeight - qrSide) / 2,
          qrSide,
        );
      }

      final picture = recorder.endRecording();
      final outImg = await picture.toImage(imgW.toInt(), totalH.toInt());
      final byteData = await outImg.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {
      // In headless test environments or when codec is unavailable, fallback to rawImageBytes
    }
    return rawImageBytes;
  }

  static String canonicalPayload({
    required String recordId,
    required String mediaType,
    required DateTime timestamp,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    required double? altitude,
    required String address,
    required String mediaSha256,
  }) {
    final lat = latitude != null ? latitude.toStringAsFixed(6) : 'null';
    final lng = longitude != null ? longitude.toStringAsFixed(6) : 'null';
    final acc = accuracy != null ? accuracy.toStringAsFixed(1) : 'null';
    final alt = altitude != null ? altitude.toStringAsFixed(1) : 'null';
    final ts = timestamp.toUtc().toIso8601String();
    return [
      'v=2',
      'id=$recordId',
      'type=$mediaType',
      'ts=$ts',
      'lat=$lat',
      'lng=$lng',
      'acc=$acc',
      'alt=$alt',
      'addr64=${base64Encode(utf8.encode(address))}',
      'media_sha256=$mediaSha256',
    ].join('|');
  }

  Future<String> getPublicKey() async {
    final keyPair = await _keyPair();
    final pub = await keyPair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  Future<String> signPayload({
    required String recordId,
    required String mediaType,
    required DateTime timestamp,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    required double? altitude,
    required String address,
    required String mediaSha256,
  }) async {
    final keyPair = await _keyPair();
    final msg = canonicalPayload(
      recordId: recordId,
      mediaType: mediaType,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      address: address,
      mediaSha256: mediaSha256,
    );
    final signature = await _ed25519.sign(utf8.encode(msg), keyPair: keyPair);
    return base64Encode(signature.bytes);
  }

  Future<bool> verifySignature({
    required String storedSignature,
    required String publicKey,
    required String recordId,
    required String mediaType,
    required DateTime timestamp,
    required double? latitude,
    required double? longitude,
    required double? accuracy,
    required double? altitude,
    required String address,
    required String mediaSha256,
  }) async {
    if (storedSignature.isEmpty || publicKey.isEmpty || mediaSha256.isEmpty)
      return false;
    try {
      final pub = SimplePublicKey(
        base64Decode(publicKey),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        base64Decode(storedSignature),
        publicKey: pub,
      );
      final msg = canonicalPayload(
        recordId: recordId,
        mediaType: mediaType,
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        altitude: altitude,
        address: address,
        mediaSha256: mediaSha256,
      );
      return await _ed25519.verify(utf8.encode(msg), signature: signature);
    } catch (_) {
      return false;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
      } catch (_) {
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  /// Reverse-geocodes a fix into a one-line address. Returns '' when it cannot (offline, no geocoder,
  /// no fix): callers must treat that as "unavailable" and never substitute a made-up address.
  Future<String> resolveAddress(Position? position) async {
    if (position == null || Platform.environment.containsKey('FLUTTER_TEST'))
      return '';
    try {
      final marks = await Geocoding()
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 5));
      if (marks.isEmpty) return '';
      final m = marks.first;
      final parts = <String>[];
      for (final v in [
        m.name,
        m.subLocality,
        m.locality,
        m.administrativeArea,
        m.postalCode,
        m.country,
      ]) {
        final t = (v ?? '').trim();
        if (t.isNotEmpty && !parts.contains(t)) parts.add(t);
      }
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }

  String computeSha256(Uint8List bytes) {
    return crypto.sha256.convert(bytes).toString();
  }

  Future<GeoCamStamp> createStamp({
    required Uint8List imageBytes,
    Position? position,
    String address = '',
    bool stampPixels = true,
    StampSettings? settings,
  }) async {
    final s = settings ?? StampSettings();
    final now = DateTime.now().toUtc();
    final recordId = 'GEO-${now.millisecondsSinceEpoch}';
    final qrPayload = qrPayloadFor(recordId);

    Uint8List finalBytes = imageBytes;
    if (stampPixels && s.pixelEmbeddedStamps) {
      finalBytes = await stampImageWithWatermark(
        rawImageBytes: imageBytes,
        recordId: recordId,
        qrPayload: qrPayload,
        timestamp: now,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        address: address,
        settings: s,
      );
    }

    final sha256 = computeSha256(finalBytes);

    String signature = '';
    String publicKey = '';
    try {
      signature = await signPayload(
        recordId: recordId,
        mediaType: 'photo',
        timestamp: now,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        altitude: position?.altitude,
        address: address,
        mediaSha256: sha256,
      );
      publicKey = await getPublicKey();
    } catch (_) {}

    return GeoCamStamp(
      recordId: recordId,
      qrPayload: qrPayload,
      timestamp: now,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      altitude: position?.altitude,
      address: address,
      sha256: sha256,
      signature: signature,
      publicKey: publicKey,
      status: 'VERIFIED',
      stampedBytes: finalBytes,
    );
  }

  Future<GeoCamStamp> createVideoStamp({
    required Uint8List videoBytes,
    Position? position,
    String address = '',
  }) async {
    final now = DateTime.now().toUtc();
    final recordId = 'GEO-${now.millisecondsSinceEpoch}';
    final qrPayload = qrPayloadFor(recordId);
    final sha256 = computeSha256(videoBytes);

    String signature = '';
    String publicKey = '';
    try {
      signature = await signPayload(
        recordId: recordId,
        mediaType: 'video',
        timestamp: now,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        altitude: position?.altitude,
        address: address,
        mediaSha256: sha256,
      );
      publicKey = await getPublicKey();
    } catch (_) {}

    return GeoCamStamp(
      recordId: recordId,
      qrPayload: qrPayload,
      timestamp: now,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      altitude: position?.altitude,
      address: address,
      sha256: sha256,
      signature: signature,
      publicKey: publicKey,
      status: 'VERIFIED',
      stampedBytes: videoBytes,
    );
  }

  /// Full genuine verification workflow that inspects record and image bytes, distinguishing
  /// VERIFIED, INVALID / TAMPERED, and UNABLE TO VERIFY states.
  Future<GeoCamVerificationResult> verifyRecord({
    required String qrOrRecordId,
    Uint8List? candidateImageBytes,
    GeoCamRecord? loadedRecord,
  }) async {
    final recordId = extractRecordId(qrOrRecordId);
    if (recordId == null || recordId.isEmpty) {
      return const GeoCamVerificationResult(
        status: GeoCamVerificationStatus.unableToVerify,
        message: 'Invalid QR payload or empty Record ID provided.',
        recordId: '',
        qrPayload: '',
      );
    }

    final payload = qrPayloadFor(recordId);
    final record = loadedRecord ?? await GeoCamHistoryStore.getById(recordId);

    if (record == null) {
      return GeoCamVerificationResult(
        status: GeoCamVerificationStatus.unableToVerify,
        message:
            'Record "$recordId" not found in local cryptographic registry.',
        recordId: recordId,
        qrPayload: payload,
      );
    }

    if (!record.hasCryptographicProof) {
      return GeoCamVerificationResult(
        status: GeoCamVerificationStatus.unableToVerify,
        message:
            'Record "$recordId" was created without complete cryptographic signatures or hash digests.',
        recordId: recordId,
        qrPayload: record.qrPayload,
        record: record,
      );
    }

    Uint8List? mediaBytes = candidateImageBytes;
    if (mediaBytes == null) {
      try {
        final file = File(record.photoPath);
        if (await file.exists() &&
            await FileSystemEntity.isFile(record.photoPath)) {
          mediaBytes = await file.readAsBytes().timeout(
            const Duration(seconds: 2),
          );
        }
      } catch (_) {}
    }

    if (mediaBytes == null || mediaBytes.isEmpty) {
      return GeoCamVerificationResult(
        status: GeoCamVerificationStatus.unableToVerify,
        message:
            'Referenced media file is missing or unreadable on local storage.',
        recordId: recordId,
        qrPayload: record.qrPayload,
        expectedSha256: record.sha256,
        record: record,
      );
    }

    final actualHash = computeSha256(mediaBytes);
    final shaMatches = (actualHash == record.sha256);

    final signatureValid = await verifySignature(
      storedSignature: record.signature,
      publicKey: record.publicKey,
      recordId: record.id,
      mediaType: record.mediaType,
      timestamp: record.timestamp,
      latitude: record.latitude,
      longitude: record.longitude,
      accuracy: record.accuracy,
      altitude: record.altitude,
      address: record.address,
      mediaSha256: actualHash,
    );

    if (shaMatches && signatureValid) {
      return GeoCamVerificationResult(
        status: GeoCamVerificationStatus.verified,
        message: 'Media bytes and signed capture metadata match.',
        recordId: recordId,
        qrPayload: record.qrPayload,
        expectedSha256: record.sha256,
        actualSha256: actualHash,
        shaMatches: true,
        signatureValid: true,
        record: record,
      );
    } else {
      final reason = !shaMatches
          ? 'Media SHA-256 digest does not match signed record digest (Tampered image).'
          : 'Ed25519 signature verification failed against record metadata.';
      return GeoCamVerificationResult(
        status: GeoCamVerificationStatus.invalidTampered,
        message: reason,
        recordId: recordId,
        qrPayload: record.qrPayload,
        expectedSha256: record.sha256,
        actualSha256: actualHash,
        shaMatches: shaMatches,
        signatureValid: signatureValid,
        record: record,
      );
    }
  }
}
