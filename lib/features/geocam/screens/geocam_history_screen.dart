import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../services/geocam_history_store.dart';
import '../services/geocam_verification_service.dart';
import '../services/geocam_sync_service.dart';
import 'geocam_verification_dialog.dart';

import 'package:share_plus/share_plus.dart';

class GeoCamHistoryScreen extends StatefulWidget {
  const GeoCamHistoryScreen({super.key});

  @override
  State<GeoCamHistoryScreen> createState() => _GeoCamHistoryScreenState();
}

class _GeoCamHistoryScreenState extends State<GeoCamHistoryScreen> {
  List<GeoCamRecord> _records = [];
  bool _isLoading = true;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isLoading = false;
    } else {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await GeoCamHistoryStore.load();
    if (mounted) {
      setState(() {
        _records = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(GeoCamRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Capture?'),
        content: Text(
          'Remove verification record ${record.id} from local history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GeoCamHistoryStore.delete(record);
      await _loadHistory();
    }
  }

  void _inspectRecord(GeoCamRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GeoCamDetailScreen(record: record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('GeoCam History'),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? 'List View' : '3-Column Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Verify QR / Record',
            onPressed: () {
              showGeoCamVerificationDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Captures Recorded Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Take photos from the GeoCam screen to generate\ntamper-proof cryptographic records.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : _isGridView
          ? GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                return InkWell(
                  onTap: () => _inspectRecord(record),
                  onLongPress: () => _deleteRecord(record),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: Colors.black87,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(record.photoPath),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: Colors.grey.shade900,
                              child: Icon(
                                record.mediaType == 'video'
                                    ? Icons.videocam_rounded
                                    : Icons.photo_rounded,
                                color: Colors.white54,
                                size: 28,
                              ),
                            ),
                          ),
                          if (record.mediaType == 'video')
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.75),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              child: Text(
                                record.id.length > 10
                                    ? record.id.substring(record.id.length - 10)
                                    : record.id,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = _records[index];
                return InkWell(
                  onTap: () => _inspectRecord(record),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassFillStrong,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(record.photoPath),
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey.shade900,
                              child: Icon(
                                record.mediaType == 'video'
                                    ? Icons.videocam_rounded
                                    : Icons.broken_image_outlined,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      record.id,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (record.mediaType == 'video') ...[
                                    Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'VIDEO',
                                        style: TextStyle(
                                          color: Colors.indigo,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      record.hasCryptographicProof
                                          ? 'SIGNED'
                                          : 'VERIFIED',
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: record.isRemoteConfirmed
                                          ? AppColors.success.withValues(
                                              alpha: 0.15,
                                            )
                                          : record.isSynchronized
                                          ? Colors.blue.withValues(alpha: 0.12)
                                          : record.isSyncFailed
                                          ? AppColors.error.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.grey.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      record.isRemoteConfirmed
                                          ? 'ONLINE'
                                          : record.isSynchronized
                                          ? 'SYNCED'
                                          : record.isSyncFailed
                                          ? 'FAILED'
                                          : 'LOCAL',
                                      style: TextStyle(
                                        color: record.isRemoteConfirmed
                                            ? AppColors.success
                                            : record.isSynchronized
                                            ? Colors.blue.shade700
                                            : record.isSyncFailed
                                            ? AppColors.error
                                            : Colors.grey.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.formattedCoordinates,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SHA: ${record.sha256.length > 12 ? record.sha256.substring(0, 12) : record.sha256}...',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => _deleteRecord(record),
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

class GeoCamDetailScreen extends StatefulWidget {
  final GeoCamRecord record;

  const GeoCamDetailScreen({super.key, required this.record});

  @override
  State<GeoCamDetailScreen> createState() => _GeoCamDetailScreenState();
}

class _GeoCamDetailScreenState extends State<GeoCamDetailScreen> {
  late GeoCamRecord _record;
  bool _isReverifying = false;
  bool? _integrityValid;
  bool? _signatureValid;
  bool _isExporting = false;
  bool _isSyncing = false;
  bool _isCheckingRemote = false;
  GeoCamRemoteCheckResult? _remoteResult;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
  }

  Future<void> _shareMedia() async {
    final r = _record;
    if (!r.isSynchronized && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
          content: Text(
            'Sharing original stamped media. Note: Web verification URL will report '
            '"Not Found" until you synchronize this capture online.',
          ),
        ),
      );
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(r.photoPath)],
          text:
              'CampusOS GeoCam Verified Capture\n'
              'Record ID: ${r.id}\n'
              'Verification URL: ${r.qrPayload}\n'
              'SHA-256: ${r.sha256}',
          subject: 'CampusOS GeoCam Evidence ${r.id}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to share media: $e'),
          ),
        );
      }
    }
  }

  Future<void> _saveToGalleryRetry() async {
    try {
      final success = await GeoCamHistoryStore.saveToGallery(_record);
      final updated = await GeoCamHistoryStore.getById(_record.id);
      if (mounted) {
        setState(() {
          if (updated != null) _record = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? AppColors.success : AppColors.error,
            content: Text(
              success
                  ? 'Saved to phone Gallery in "CampusOS GeoCam"'
                  : 'Failed to save to gallery: ${_record.galleryError ?? "Unknown error"}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to save to gallery: $e'),
          ),
        );
      }
    }
  }

  Future<void> _makeVerifiableOnline() async {
    final confirmed = await showGeoCamSyncDisclosureDialog(
      context,
      recordId: _record.id,
      mediaType: _record.mediaType,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSyncing = true);
    final res = await GeoCamSyncService.instance.syncRecord(_record);
    final reloaded = await GeoCamHistoryStore.getById(_record.id);
    if (mounted) {
      setState(() {
        _isSyncing = false;
        if (reloaded != null) _record = reloaded;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: res.success ? AppColors.success : AppColors.error,
          content: Text(res.message),
        ),
      );
    }
  }

  Future<void> _checkRemoteVerification() async {
    setState(() => _isCheckingRemote = true);
    final res = await GeoCamSyncService.instance.checkRemoteVerification(
      _record.id,
    );
    final reloaded = await GeoCamHistoryStore.getById(_record.id);
    if (mounted) {
      setState(() {
        _isCheckingRemote = false;
        _remoteResult = res;
        if (reloaded != null) _record = reloaded;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: res.isVerified
              ? AppColors.success
              : (res.isNotFound ? Colors.orange.shade700 : AppColors.error),
          content: Text(res.message),
        ),
      );
    }
  }

  Future<void> _verifyIntegrity() async {
    setState(() => _isReverifying = true);
    try {
      final res = await GeoCamVerificationService.instance.verifyRecord(
        qrOrRecordId: _record.id,
        loadedRecord: _record,
      );

      setState(() {
        _integrityValid = res.shaMatches;
        _signatureValid = res.signatureValid;
        _isReverifying = false;
      });
    } catch (_) {
      setState(() {
        _integrityValid = false;
        _signatureValid = false;
        _isReverifying = false;
      });
    }
  }

  Future<void> _exportMedia() async {
    setState(() => _isExporting = true);
    try {
      final path = await GeoCamHistoryStore.exportToGalleryOrDownloads(_record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Exported successfully to: $path'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Export failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(r.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Media',
            onPressed: _shareMedia,
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Export Media',
            onPressed: _isExporting ? null : _exportMedia,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Full photo + footer, uncropped (BoxFit.contain keeps the metadata footer visible).
                Image.file(
                  File(r.photoPath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    height: 280,
                    width: double.infinity,
                    color: Colors.grey.shade900,
                    child: Center(
                      child: Icon(
                        r.mediaType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                if (r.mediaType == 'video') ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            color: Colors.amberAccent,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VIDEO CLIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Embedded GeoCam QR Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Embedded GeoCam QR Code',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VERIFIABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.glassFillStrong,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: r.qrPayload,
                        version: QrVersions.auto,
                        size: 105,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verification Link:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            r.qrPayload,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              showGeoCamVerificationDialog(
                                context,
                                initialRecordId: r.id,
                                initialRecord: r,
                              );
                            },
                            icon: const Icon(Icons.verified_outlined, size: 16),
                            label: const Text(
                              'Open Verifier',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Online Web Verification & Synchronization Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          r.isRemoteConfirmed
                              ? Icons.cloud_done_rounded
                              : r.isSynchronized
                              ? Icons.cloud_queue_rounded
                              : Icons.cloud_off_rounded,
                          color: r.isRemoteConfirmed
                              ? AppColors.success
                              : r.isSynchronized
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Online Web Verification',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    _buildSyncStatusBadge(r),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getSyncDescription(r),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (r.syncError != null && r.syncError!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Error: ${r.syncError}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_remoteResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _remoteResult!.isVerified
                          ? AppColors.success.withValues(alpha: 0.1)
                          : (_remoteResult!.isNotFound
                                ? Colors.orange.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _remoteResult!.isVerified
                              ? Icons.check_circle_outline_rounded
                              : (_remoteResult!.isNotFound
                                    ? Icons.info_outline
                                    : Icons.cancel_outlined),
                          color: _remoteResult!.isVerified
                              ? AppColors.success
                              : (_remoteResult!.isNotFound
                                    ? Colors.orange.shade800
                                    : AppColors.error),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _remoteResult!.message,
                            style: TextStyle(
                              color: _remoteResult!.isVerified
                                  ? AppColors.success
                                  : (_remoteResult!.isNotFound
                                        ? Colors.orange.shade900
                                        : AppColors.error),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (r.syncedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last Synchronized: ${r.syncedAt!.toLocal().toString().split('.').first}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (!r.isSynchronized) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSyncing ? null : _makeVerifiableOnline,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        _isSyncing
                            ? 'Synchronizing...'
                            : (r.isSyncFailed
                                  ? 'Retry Online Sync'
                                  : 'Make QR Verifiable Online'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: r.isSyncFailed
                            ? AppColors.error
                            : AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isCheckingRemote
                              ? null
                              : _checkRemoteVerification,
                          icon: _isCheckingRemote
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.verified_user_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _isCheckingRemote
                                ? 'Checking...'
                                : 'Check Server Status',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _isSyncing ? null : _makeVerifiableOnline,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Re-sync'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Phone Gallery Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      r.isSavedToGallery
                          ? Icons.photo_library_rounded
                          : Icons.photo_library_outlined,
                      color: r.isSavedToGallery
                          ? AppColors.success
                          : AppColors.accent,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Phone Gallery (CampusOS GeoCam)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: r.isSavedToGallery
                            ? AppColors.success.withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.isSavedToGallery ? 'IN GALLERY' : 'NOT IN GALLERY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r.isSavedToGallery
                              ? AppColors.success
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r.isSavedToGallery
                      ? 'Saved directly to your device Photos in the "CampusOS GeoCam" album.'
                      : (r.galleryError != null
                            ? 'Gallery save error: ${r.galleryError}'
                            : 'Not saved to public device Photos yet. Tap below to save.'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (!r.isSavedToGallery) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saveToGalleryRetry,
                    icon: const Icon(Icons.save_alt_rounded, size: 16),
                    label: const Text(
                      'Save to Phone Gallery',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: AppColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cryptographic Verification Audit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildAuditRow('Record ID', r.id),
                _buildAuditRow('Media Type', r.mediaType.toUpperCase()),
                _buildAuditRow('Timestamp', r.timestamp.toLocal().toString()),
                _buildAuditRow('Coordinates', r.formattedCoordinates),
                _buildAuditRow(
                  'Accuracy',
                  r.accuracy != null
                      ? '±${r.accuracy!.toStringAsFixed(1)}m'
                      : 'N/A',
                ),
                _buildAuditRow('Payload SHA-256', r.sha256, isMonospace: true),
                if (r.signature.isNotEmpty)
                  _buildAuditRow(
                    'Ed25519 Signature',
                    r.signature.length > 24
                        ? '${r.signature.substring(0, 24)}...'
                        : r.signature,
                    isMonospace: true,
                  ),
                if (r.publicKey.isNotEmpty)
                  _buildAuditRow(
                    'Device Public Key',
                    r.publicKey.length > 24
                        ? '${r.publicKey.substring(0, 24)}...'
                        : r.publicKey,
                    isMonospace: true,
                  ),
                const SizedBox(height: 12),
                if (_integrityValid != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _integrityValid!
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _integrityValid!
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _integrityValid!
                                  ? AppColors.success
                                  : AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _integrityValid!
                                    ? 'Image bytes match stored SHA-256 hash.'
                                    : 'Integrity check failed! Image has been modified.',
                                style: TextStyle(
                                  color: _integrityValid!
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_signatureValid != null &&
                            r.hasCryptographicProof) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _signatureValid!
                                    ? Icons.lock_outline
                                    : Icons.lock_open,
                                color: _signatureValid!
                                    ? AppColors.success
                                    : AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _signatureValid!
                                      ? 'Ed25519 signature valid (Device-signed authenticity confirmed).'
                                      : 'Ed25519 signature verification failed!',
                                  style: TextStyle(
                                    color: _signatureValid!
                                        ? AppColors.success
                                        : AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isReverifying ? null : _verifyIntegrity,
                        icon: _isReverifying
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.security_update_good_rounded),
                        label: const Text('Audit Proof'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isExporting ? null : _exportMedia,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export Media'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareMedia,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Stamped Media'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBadge(GeoCamRecord record) {
    if (_isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'SYNCING',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );
    }
    if (record.isRemoteConfirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'REMOTE VERIFIED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
      );
    }
    if (record.isSynchronized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'SYNCHRONIZED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );
    }
    if (record.isSyncFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'SYNC FAILED',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PENDING',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _getSyncDescription(GeoCamRecord record) {
    if (record.isRemoteConfirmed) {
      return 'The official GeoCam web server has cryptographically verified this record. '
          'Media bytes and Ed25519 signature are confirmed authentic on the web.';
    }
    if (record.isSynchronized) {
      return 'Record has been synchronized to https://geocam-server.onrender.com. '
          'Anyone scanning the embedded QR link can verify the authentic capture in their web browser.';
    }
    if (record.isSyncFailed) {
      return 'Synchronization to the GeoCam server failed. '
          'Local cryptographic proofs remain intact. Tap below to retry uploading.';
    }
    if (record.syncPermanent) {
      return 'The server rejected this record, so it will not be retried automatically.';
    }
    return 'Stored locally and queued for automatic upload (retries with back-off when the server is unreachable). '
        'Until it uploads, scanning the QR reports "Record Not Found".';
  }
}
