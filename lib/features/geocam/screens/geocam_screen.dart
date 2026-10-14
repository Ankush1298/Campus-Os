import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';

class GeoCamScreen extends StatefulWidget {
  const GeoCamScreen({super.key});

  @override
  State<GeoCamScreen> createState() => _GeoCamScreenState();
}

class _GeoCamScreenState extends State<GeoCamScreen> {
  final bool _isGpsLocked = true;
  final String _currentCoordinates = '28.6139° N, 77.2090° E';
  final String _campusZone = 'North Campus Academic Block (Zone A)';
  bool _isCapturing = false;

  void _simulateCapture() {
    setState(() => _isCapturing = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('GeoCam: Cryptographically stamped photo saved!'),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoCam Integration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('About GeoCam Engine'),
                  content: const Text(
                    'GeoCam provides tamper-proof, location-aware image verification '
                    'with embedded GPS coordinates, cryptographic hashing, and campus geofencing.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // GPS Lock & Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isGpsLocked ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isGpsLocked ? Icons.location_on : Icons.location_off,
                    color: _isGpsLocked ? AppColors.primaryLight : AppColors.error,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'GPS Status: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          StatusBadge.status(_isGpsLocked ? 'READY' : 'ERROR'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentCoordinates,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        _campusZone,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Viewfinder simulation / camera launcher card
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Viewfinder grid overlay
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.filter_center_focus_rounded,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                // Stamp overlay HUD
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'CRYPTO-STAMP ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ISO 200 • 1/120s',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom HUD with watermark preview
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GEO: $_currentCoordinates',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
                        ),
                        Text(
                          'TIME: ${DateTime.now().toUtc().toIso8601String().substring(0, 19)}Z',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                        ),
                        const Text(
                          'HASH: SHA256: 7f83b165...e3b0c442',
                          style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Shutter Action Button
          ElevatedButton.icon(
            onPressed: _isCapturing ? null : _simulateCapture,
            icon: _isCapturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.camera_alt_rounded),
            label: Text(_isCapturing ? 'Processing Stamp...' : 'Capture Verified Geo-Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Information / Integration card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Repository',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'GitHub: Ankush1298/geocam\nNative camera, EXIF watermarking, and SHA-256 verification bridge ready.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
