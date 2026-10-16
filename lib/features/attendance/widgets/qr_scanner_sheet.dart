import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_session.dart';
import '../services/attendance_service.dart';

class QrScannerSheet extends StatefulWidget {
  final UserSession session;
  final VoidCallback? onAttendanceMarked;

  const QrScannerSheet({
    super.key,
    required this.session,
    this.onAttendanceMarked,
  });

  static Future<void> show(
    BuildContext context, {
    required UserSession session,
    VoidCallback? onAttendanceMarked,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QrScannerSheet(
        session: session,
        onAttendanceMarked: onAttendanceMarked,
      ),
    );
  }

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet>
    with SingleTickerProviderStateMixin {
  // Real QR decoding. Disabled under flutter_test (no camera plugin there); manual entry still works.
  MobileScannerController? _scanner;
  bool _isSubmitting = false;
  String? _statusMessage;
  Color? _statusColor;
  IconData? _statusIcon;
  final TextEditingController _tokenInputController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _scanner = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionTimeoutMs: 1500,
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        _submitToken(v);
        return;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanner?.dispose();
    _tokenInputController.dispose();
    super.dispose();
  }

  Future<void> _submitToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final res = await AttendanceService.instance.scanQrAttendance(
        qrToken: trimmed,
        isDemo: widget.session.isDemo,
      );

      final phase = res['phase']?.toString() ?? '';
      final status = res['status']?.toString() ?? '';
      final msg =
          res['message'] ??
          (phase == 'end' || status == 'present'
              ? 'Attendance Verified! Marked Present.'
              : 'Start scan recorded ($phase). Scan again at class end.');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = msg;
          _statusColor = AppColors.success;
          _statusIcon = Icons.check_circle_rounded;
        });
        widget.onAttendanceMarked?.call();
      }
    } on ApiException catch (e) {
      String errText = e.message;
      Color color = AppColors.error;
      IconData icon = Icons.error_outline_rounded;

      if (e.statusCode == 410 || e.message.toLowerCase().contains('expired')) {
        errText = 'Attendance QR token has expired. Request teacher to start session.';
        color = const Color(0xFFEF4444);
        icon = Icons.timer_off_rounded;
      } else if (e.statusCode == 409) {
        if (e.message.contains('start_not_recorded') ||
            e.message.toLowerCase().contains('start scan')) {
          errText = 'End scan rejected: Start attendance was never recorded for this class.';
          color = const Color(0xFFEF4444);
          icon = Icons.block_rounded;
        } else {
          errText = 'Scan already recorded for this attendance phase.';
          color = const Color(0xFFF59E0B);
          icon = Icons.info_outline_rounded;
        }
      } else if (e.statusCode == 403) {
        errText =
            'Unauthorized: You are not enrolled in the section for this class.';
        color = const Color(0xFFEF4444);
        icon = Icons.cancel_outlined;
      } else if (e.statusCode == 404) {
        errText = 'Invalid or unrecognized QR token.';
        color = const Color(0xFFEF4444);
        icon = Icons.qr_code_scanner_rounded;
      } else if (e.statusCode == 0) {
        errText = 'Network connection failure. Check server reachability.';
        color = const Color(0xFF6B7280);
        icon = Icons.wifi_off_rounded;
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = errText;
          _statusColor = color;
          _statusIcon = icon;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _statusMessage = 'Submission error: $e';
          _statusColor = AppColors.error;
          _statusIcon = Icons.error_outline_rounded;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1B3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Scan Classroom QR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.session.isDemo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Text(
                              'DEMO',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Text(
                      'Two-Phase Scheduled Attendance',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scanner viewfinder area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera preview or dark reticle
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black,
                      child: _scanner != null
                          ? MobileScanner(
                              controller: _scanner!,
                              onDetect: _onDetect,
                              errorBuilder: (context, error) => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Camera unavailable. Allow camera permission, or type the code shown on the classroom display below.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: 72,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Point camera at Classroom Display',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  // Animated scanner reticle
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Animated scan line
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Positioned(
                              top: _animationController.value * 220,
                              left: 10,
                              right: 10,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.primary,
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.8,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Submitting spinner overlay
                  if (_isSubmitting)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Status Banner (if message present)
          if (_statusMessage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_statusColor ?? AppColors.primary).withValues(
                  alpha: 0.15,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_statusColor ?? AppColors.primary).withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon ?? Icons.info_outline_rounded,
                    color: _statusColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Manual token entry fallback (allows tests & keyboard token submission)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tokenInputController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter QR token manually...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitToken(_tokenInputController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
