import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../services/geocam_history_store.dart';
import '../services/geocam_verification_service.dart';

Future<void> showGeoCamVerificationDialog(
  BuildContext context, {
  String? initialRecordId,
  GeoCamRecord? initialRecord,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => GeoCamVerificationDialog(
      initialRecordId: initialRecordId,
      initialRecord: initialRecord,
    ),
  );
}

class GeoCamVerificationDialog extends StatefulWidget {
  final String? initialRecordId;
  final GeoCamRecord? initialRecord;

  const GeoCamVerificationDialog({
    super.key,
    this.initialRecordId,
    this.initialRecord,
  });

  @override
  State<GeoCamVerificationDialog> createState() =>
      _GeoCamVerificationDialogState();
}

class _GeoCamVerificationDialogState extends State<GeoCamVerificationDialog> {
  late final TextEditingController _inputController;
  bool _isVerifying = false;
  GeoCamVerificationResult? _result;
  String? _errorMessage;
  List<GeoCamRecord> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    final defaultText =
        widget.initialRecord?.qrPayload ??
        (widget.initialRecordId != null && widget.initialRecordId!.isNotEmpty
            ? GeoCamVerificationService.qrPayloadFor(widget.initialRecordId!)
            : '');
    _inputController = TextEditingController(text: defaultText);
    _loadRecentRecords();
  }

  Future<void> _loadRecentRecords() async {
    try {
      final records = await GeoCamHistoryStore.load();
      if (mounted) {
        setState(() {
          _recentRecords = records;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _runVerification({Uint8List? overrideBytes}) async {
    final query = _inputController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid GeoCam QR URL or Record ID.';
        _result = null;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final res = await GeoCamVerificationService.instance.verifyRecord(
        qrOrRecordId: query,
        candidateImageBytes: overrideBytes,
        loadedRecord: widget.initialRecord,
      );

      if (mounted) {
        setState(() {
          _result = res;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Verification error: $e';
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GeoCam QR Verification',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Verify cryptographic proof and SHA-256 digest',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Query Input Box
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        labelText: 'QR Code URL or Record ID',
                        hintText: 'https://geocam-server.onrender.com/GEO-...',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                          ),
                          tooltip: 'Paste from Clipboard',
                          onPressed: () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            if (data?.text != null &&
                                data!.text!.trim().isNotEmpty) {
                              setState(() {
                                _inputController.text = data.text!.trim();
                              });
                            }
                          },
                        ),
                      ),
                      onSubmitted: (_) => _runVerification(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isVerifying ? null : () => _runVerification(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ],
              ),
              if (_recentRecords.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Recent: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      for (final r in _recentRecords.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(
                              r.id,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _inputController.text = r.qrPayload;
                              });
                              _runVerification();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Verification Results Area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_result != null) ...[
                        _buildStatusBanner(_result!),
                        const SizedBox(height: 14),
                        _buildVerificationDetails(_result!),
                      ] else if (!_isVerifying) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Enter or scan a GeoCam QR payload to audit image authenticity, Ed25519 signature, and tamper detection.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(GeoCamVerificationResult r) {
    Color bannerBg;
    Color bannerBorder;
    Color textColor;
    IconData icon;
    String title;

    switch (r.status) {
      case GeoCamVerificationStatus.verified:
        bannerBg = const Color(0xFFECFDF5);
        bannerBorder = const Color(0xFF10B981);
        textColor = const Color(0xFF065F46);
        icon = Icons.verified_user_rounded;
        title = 'VERIFIED AUTHENTIC';
        break;
      case GeoCamVerificationStatus.invalidTampered:
        bannerBg = const Color(0xFFFEF2F2);
        bannerBorder = const Color(0xFFEF4444);
        textColor = const Color(0xFF991B1B);
        icon = Icons.gpp_bad_rounded;
        title = 'INVALID / TAMPERED RECORD';
        break;
      case GeoCamVerificationStatus.unableToVerify:
        bannerBg = const Color(0xFFFFFBEB);
        bannerBorder = const Color(0xFFF59E0B);
        textColor = const Color(0xFF92400E);
        icon = Icons.help_outline_rounded;
        title = 'UNABLE TO VERIFY';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        border: Border.all(color: bannerBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: bannerBorder, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.message,
                  style: TextStyle(color: textColor, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDetails(GeoCamVerificationResult r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cryptographic Audit Breakdown',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 16),
          _detailRow('Record ID', r.recordId.isNotEmpty ? r.recordId : 'None'),
          _detailRow(
            'QR Payload',
            r.qrPayload.isNotEmpty ? r.qrPayload : 'None',
            isUrl: true,
          ),
          if (r.expectedSha256 != null)
            _detailRow('Expected SHA-256', r.expectedSha256!, isMono: true),
          if (r.actualSha256 != null)
            _detailRow('Actual SHA-256', r.actualSha256!, isMono: true),
          if (r.shaMatches != null)
            _detailRow(
              'SHA-256 Match',
              r.shaMatches! ? 'MATCH CONFIRMED' : 'DIGEST MISMATCH',
              highlightColor: r.shaMatches!
                  ? AppColors.success
                  : AppColors.error,
            ),
          if (r.signatureValid != null)
            _detailRow(
              'Ed25519 Signature',
              r.signatureValid!
                  ? 'CRYPTOGRAPHICALLY VALID'
                  : 'INVALID SIGNATURE',
              highlightColor: r.signatureValid!
                  ? AppColors.success
                  : AppColors.error,
            ),
          if (r.record != null) ...[
            _detailRow('Capture Coordinates', r.record!.formattedCoordinates),
            _detailRow('Timestamp', r.record!.timestamp.toLocal().toString()),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    bool isMono = false,
    bool isUrl = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFamily: (isMono || isUrl) ? 'monospace' : null,
              color:
                  highlightColor ??
                  (isUrl ? AppColors.primary : AppColors.textPrimary),
              fontWeight: (highlightColor != null || isUrl)
                  ? FontWeight.bold
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
