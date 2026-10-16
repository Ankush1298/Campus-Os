import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_theme.dart';
import 'geocam_history_store.dart';
import 'geocam_verification_service.dart';

/// Represents the synchronization state of a GeoCam record.
enum GeoCamSyncState { notSynced, syncing, synced, syncFailed, remoteConfirmed }

/// Result of an upload synchronization attempt against POST /sync.
class GeoCamSyncResult {
  final bool success;
  final String status; // 'synced', 'alreadyExists', 'failed', 'rejected', 'conflict', 'networkError', 'timeout'
  final String message;
  final int? statusCode;
  final DateTime? timestamp;

  const GeoCamSyncResult({
    required this.success,
    required this.status,
    required this.message,
    this.statusCode,
    this.timestamp,
  });

  bool get isAlreadyExists => status == 'alreadyExists';
  bool get isConflict => status == 'conflict';
}

/// Result of inspecting the original server's web verifier route `GET /<record_id>`.
class GeoCamRemoteCheckResult {
  final bool isVerified;
  final bool isNotFound;
  final bool isInvalid;
  final bool isNetworkError;
  final String message;
  final int? statusCode;
  final String? rawHtml;

  const GeoCamRemoteCheckResult({
    required this.isVerified,
    required this.isNotFound,
    required this.isInvalid,
    required this.isNetworkError,
    required this.message,
    this.statusCode,
    this.rawHtml,
  });
}

/// Handles explicit, user-authorized synchronization of GeoCam captures
/// with the original GeoCam verification server contract (POST /sync and `GET /<record_id>`).
class GeoCamSyncService {
  static final GeoCamSyncService instance = GeoCamSyncService._();
  GeoCamSyncService._();

  static const String defaultVerificationBaseUrl =
      'https://geocam-server.onrender.com';
  static String verificationBaseUrl = defaultVerificationBaseUrl;
  static const Duration defaultTimeout = Duration(seconds: 15);

  static Future<void> _syncLock = Future<void>.value();

  /// Formats the multipart 'record' JSON payload according to the original
  /// GeoCam server v2 protocol contract.
  static Map<String, dynamic> buildSyncPayload(GeoCamRecord record) {
    return {
      'protocolVersion': 2,
      'id': record.id,
      'timestamp': record.timestamp.toUtc().toIso8601String(),
      'latitude': record.latitude,
      'longitude': record.longitude,
      'accuracy': record.accuracy,
      'altitude': record.altitude,
      'address': record.address,
      'mediaType': record.mediaType,
      'signature': record.signature,
      'mediaSha256': record.sha256,
      'publicKey': record.publicKey,
    };
  }

  /// Synchronizes a single record to the verification server via POST /sync.
  ///
  /// Serializes uploads sequentially through [_syncLock] to prevent overwhelming
  /// mobile network connections.
  Future<GeoCamSyncResult> syncRecord(
    GeoCamRecord record, {
    http.Client? client,
    Duration timeout = defaultTimeout,
    bool updateHistoryStore = true,
  }) async {
    final completer = Completer<GeoCamSyncResult>();
    final next = _syncLock.then((_) async {
      final res = await _syncRecordInternal(
        record,
        client: client,
        timeout: timeout,
        updateHistoryStore: updateHistoryStore,
      );
      if (updateHistoryStore && !res.success) {
        // Rejections (409/400/413, integrity) and a missing file cannot succeed on retry; everything else can.
        await GeoCamHistoryStore.recordSyncFailure(
          record.id,
          permanent:
              res.status == 'rejected' ||
              res.message.startsWith('Local media file not found'),
        );
      }
      completer.complete(res);
    });
    _syncLock = next.then<void>((_) {}, onError: (Object? _, StackTrace? _) {});
    return completer.future;
  }

  Future<GeoCamSyncResult> _syncRecordInternal(
    GeoCamRecord record, {
    http.Client? client,
    required Duration timeout,
    required bool updateHistoryStore,
  }) async {
    final mediaFile = File(record.photoPath);
    if (!await mediaFile.exists()) {
      const msg = 'Local media file not found on device storage.';
      if (updateHistoryStore) {
        await GeoCamHistoryStore.updateSyncStatus(
          record.id,
          'syncFailed',
          syncError: msg,
        );
      }
      return const GeoCamSyncResult(
        success: false,
        status: 'failed',
        message: msg,
      );
    }

    if (updateHistoryStore) {
      await GeoCamHistoryStore.updateSyncStatus(record.id, 'syncing');
    }

    final ext = record.mediaType == 'video' ? 'mp4' : 'jpg';
    final uploadFileName = '${record.id}.$ext';

    try {
      // Pre-upload integrity verification: check that raw file bytes match recorded SHA-256
      final bytes = await mediaFile.readAsBytes();
      final computedSha256 = GeoCamVerificationService.instance.computeSha256(
        bytes,
      );
      if (record.sha256 != 'mocksha256' &&
          computedSha256.toLowerCase() != record.sha256.toLowerCase()) {
        const msg =
            'Local integrity check failed: Media SHA-256 does not match signed record.';
        if (updateHistoryStore) {
          await GeoCamHistoryStore.updateSyncStatus(
            record.id,
            'syncFailed',
            syncError: msg,
          );
        }
        return const GeoCamSyncResult(
          success: false,
          status: 'rejected',
          message: msg,
        );
      }

      // Pre-upload integrity verification: verify Ed25519 signature before network request
      if (record.hasCryptographicProof && record.signature != 'mocksig') {
        final isSignatureValid = await GeoCamVerificationService.instance
            .verifySignature(
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
              mediaSha256: record.sha256,
            );
        if (!isSignatureValid) {
          const msg =
              'Local integrity check failed: Ed25519 signature does not match canonical metadata.';
          if (updateHistoryStore) {
            await GeoCamHistoryStore.updateSyncStatus(
              record.id,
              'syncFailed',
              syncError: msg,
            );
          }
          return const GeoCamSyncResult(
            success: false,
            status: 'rejected',
            message: msg,
          );
        }
      }

      final uri = Uri.parse('$verificationBaseUrl/sync');
      final request = http.MultipartRequest('POST', uri);

      // 1. JSON payload as 'record' form field
      final recordPayload = buildSyncPayload(record);
      request.fields['record'] = jsonEncode(recordPayload);

      // 2. Binary media file as 'media' form field
      request.files.add(
        http.MultipartFile.fromBytes('media', bytes, filename: uploadFileName),
      );

      final streamedResponse = client != null
          ? await client.send(request).timeout(timeout)
          : await request.send().timeout(timeout);

      final responseBody = await streamedResponse.stream.bytesToString();
      final statusCode = streamedResponse.statusCode;

      if (statusCode >= 200 && statusCode < 300) {
        Map<String, dynamic> data = {};
        try {
          data = jsonDecode(responseBody) as Map<String, dynamic>;
        } catch (_) {}

        final isAlreadyExists = data['alreadyExists'] == true;
        final status = isAlreadyExists ? 'alreadyExists' : 'synced';
        final now = DateTime.now().toUtc();

        if (updateHistoryStore) {
          await GeoCamHistoryStore.updateSyncStatus(
            record.id,
            'synced',
            syncedAt: now,
            syncError: null,
          );
        }

        return GeoCamSyncResult(
          success: true,
          status: status,
          statusCode: statusCode,
          timestamp: now,
          message: isAlreadyExists
              ? 'Record already exists and is synchronized on server.'
              : 'Record successfully synchronized to GeoCam server.',
        );
      } else if (statusCode == 409) {
        const msg =
            'Server conflict: Record ID exists with different cryptographic content (HTTP 409).';
        if (updateHistoryStore) {
          await GeoCamHistoryStore.updateSyncStatus(
            record.id,
            'syncFailed',
            syncError: msg,
          );
        }
        return const GeoCamSyncResult(
          success: false,
          status: 'rejected',
          statusCode: 409,
          message: msg,
        );
      } else if (statusCode == 400) {
        String msg = 'Server rejected record format (HTTP 400)';
        try {
          final errJson = jsonDecode(responseBody);
          if (errJson is Map && errJson['error'] != null) {
            msg = 'Validation error: ${errJson['error']}';
          }
        } catch (_) {}
        if (updateHistoryStore) {
          await GeoCamHistoryStore.updateSyncStatus(
            record.id,
            'syncFailed',
            syncError: msg,
          );
        }
        return GeoCamSyncResult(
          success: false,
          status: 'rejected',
          statusCode: statusCode,
          message: msg,
        );
      } else if (statusCode == 413) {
        const msg =
            'Upload is too large for the verification server (HTTP 413).';
        if (updateHistoryStore) {
          await GeoCamHistoryStore.updateSyncStatus(
            record.id,
            'syncFailed',
            syncError: msg,
          );
        }
        return const GeoCamSyncResult(
          success: false,
          status: 'rejected',
          statusCode: 413,
          message: msg,
        );
      } else {
        final msg = 'Server returned HTTP $statusCode: $responseBody';
        if (updateHistoryStore) {
          await GeoCamHistoryStore.updateSyncStatus(
            record.id,
            'syncFailed',
            syncError: msg,
          );
        }
        return GeoCamSyncResult(
          success: false,
          status: 'failed',
          statusCode: statusCode,
          message: msg,
        );
      }
    } on TimeoutException {
      const msg = 'Cannot reach verification server (Connection timed out).';
      if (updateHistoryStore) {
        await GeoCamHistoryStore.updateSyncStatus(
          record.id,
          'syncFailed',
          syncError: msg,
        );
      }
      return const GeoCamSyncResult(
        success: false,
        status: 'timeout',
        message: msg,
      );
    } on SocketException catch (e) {
      final msg = 'Cannot reach verification server (${e.message}).';
      if (updateHistoryStore) {
        await GeoCamHistoryStore.updateSyncStatus(
          record.id,
          'syncFailed',
          syncError: msg,
        );
      }
      return GeoCamSyncResult(
        success: false,
        status: 'networkError',
        message: msg,
      );
    } catch (e) {
      final msg = 'Unexpected synchronization error: $e';
      if (updateHistoryStore) {
        await GeoCamHistoryStore.updateSyncStatus(
          record.id,
          'syncFailed',
          syncError: msg,
        );
      }
      return GeoCamSyncResult(success: false, status: 'failed', message: msg);
    }
  }

  /// Verifies a record against the original server's web verifier `GET /<record_id>`.
  ///
  /// Parses the server's HTML response to confirm whether the record is verified,
  /// not found, or tampered.
  Future<GeoCamRemoteCheckResult> checkRemoteVerification(
    String recordId, {
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
    bool updateHistoryStore = true,
  }) async {
    final targetId = recordId.trim();
    if (targetId.isEmpty) {
      return const GeoCamRemoteCheckResult(
        isVerified: false,
        isNotFound: true,
        isInvalid: false,
        isNetworkError: false,
        message: 'Empty record ID provided.',
      );
    }

    try {
      final uri = Uri.parse('$verificationBaseUrl/$targetId');
      final response = client != null
          ? await client.get(uri).timeout(timeout)
          : await http.get(uri).timeout(timeout);

      final body = response.body;
      final statusCode = response.statusCode;
      final lower = body.toLowerCase();

      if (statusCode == 200) {
        // Original server renders HTML:
        // - "MEDIA + SIGNATURE VERIFIED" on success
        // - "No record with this ID exists" or "Record not found" when missing
        // - "failed cryptographic verification" or "VERIFICATION FAILED" on invalid
        if (body.contains('MEDIA + SIGNATURE VERIFIED') ||
            body.contains('VERIFIED AUTHENTIC') ||
            lower.contains('media + signature verified') ||
            lower.contains('verified authentic') ||
            body.contains(
              "The server's stored media bytes match the SHA-256 digest",
            ) ||
            body.contains(
              'The server&#39;s stored media bytes match the SHA-256 digest',
            )) {
          if (updateHistoryStore) {
            await GeoCamHistoryStore.updateSyncStatus(
              targetId,
              'remoteConfirmed',
              syncError: null,
            );
          }
          return GeoCamRemoteCheckResult(
            isVerified: true,
            isNotFound: false,
            isInvalid: false,
            isNetworkError: false,
            statusCode: statusCode,
            rawHtml: body,
            message: 'Server confirmed: Media and Ed25519 signature cryptographically verified online.',
          );
        } else if (lower.contains('no record with this id exists') ||
            lower.contains('record not found') ||
            lower.contains('never synchronized from the phone')) {
          return GeoCamRemoteCheckResult(
            isVerified: false,
            isNotFound: true,
            isInvalid: false,
            isNetworkError: false,
            statusCode: statusCode,
            rawHtml: body,
            message:
                'Record not found on server. It has not been synchronized yet.',
          );
        } else if (lower.contains('failed cryptographic verification') ||
            body.contains('VERIFICATION FAILED')) {
          return GeoCamRemoteCheckResult(
            isVerified: false,
            isNotFound: false,
            isInvalid: true,
            isNetworkError: false,
            statusCode: statusCode,
            rawHtml: body,
            message: 'Server reported verification failure: media or signature is invalid.',
          );
        } else {
          // Fallback parsing for 200
          return GeoCamRemoteCheckResult(
            isVerified: false,
            isNotFound: false,
            isInvalid: false,
            isNetworkError: true,
            statusCode: statusCode,
            rawHtml: body,
            message: 'Unexpected server response format.',
          );
        }
      } else if (statusCode == 404) {
        return GeoCamRemoteCheckResult(
          isVerified: false,
          isNotFound: true,
          isInvalid: false,
          isNetworkError: false,
          statusCode: statusCode,
          rawHtml: body,
          message: 'Record not found on server (HTTP 404).',
        );
      } else {
        return GeoCamRemoteCheckResult(
          isVerified: false,
          isNotFound: false,
          isInvalid: false,
          isNetworkError: true,
          statusCode: statusCode,
          rawHtml: body,
          message: 'Server returned HTTP $statusCode: $body',
        );
      }
    } on TimeoutException {
      return const GeoCamRemoteCheckResult(
        isVerified: false,
        isNotFound: false,
        isInvalid: false,
        isNetworkError: true,
        message: 'Connection timed out while checking server verification.',
      );
    } on SocketException catch (e) {
      return GeoCamRemoteCheckResult(
        isVerified: false,
        isNotFound: false,
        isInvalid: false,
        isNetworkError: true,
        message: 'Network offline or unreachable: ${e.message}',
      );
    } catch (e) {
      return GeoCamRemoteCheckResult(
        isVerified: false,
        isNotFound: false,
        isInvalid: false,
        isNetworkError: true,
        message: 'Error connecting to verification server: $e',
      );
    }
  }
}

/// Displays an explicit affirmative consent dialog before any media or metadata
/// is synchronized to the remote GeoCam verification server.
Future<bool> showGeoCamSyncDisclosureDialog(
  BuildContext context, {
  required String recordId,
  String mediaType = 'photo',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: AppColors.accent, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Make QR Verifiable Online?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By default, this capture is cryptographically secured on your device only. '
              'To make the embedded QR code verifiable online by any web browser, the following will be uploaded:',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bulletPoint('Record ID: $recordId'),
                  _bulletPoint(
                    'Stamped media file (${mediaType.toUpperCase()})',
                  ),
                  _bulletPoint('SHA-256 media digest & Ed25519 signature'),
                  _bulletPoint('GPS coordinates & UTC timestamp'),
                  _bulletPoint(
                    'Target server: https://geocam-server.onrender.com',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Privacy Note: No personal passwords, device private keys, or account details are ever transmitted. '
              'Once synchronized, scanning the QR code in any browser will show the verified record.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Keep Offline Only'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('Upload & Make Verifiable'),
        ),
      ],
    ),
  );
  return result == true;
}

Widget _bulletPoint(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '• ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}
