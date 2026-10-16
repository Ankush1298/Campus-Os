import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../attendance/screens/attendance_screen.dart';
import '../models/stamp_settings.dart';
import '../services/geocam_auto_sync.dart';
import '../services/geocam_history_store.dart';
import '../services/geocam_verification_service.dart';
import '../services/geocam_sync_service.dart';
import 'geocam_history_screen.dart';
import 'geocam_settings_sheet.dart';
import 'geocam_verification_dialog.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class GeoCamScreen extends StatefulWidget {
  const GeoCamScreen({super.key});

  @override
  State<GeoCamScreen> createState() => _GeoCamScreenState();
}

class _GeoCamScreenState extends State<GeoCamScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isSyncingCaptured = false;
  bool _capturedSynced = false;
  String? _capturedSyncMessage;
  String? _cameraErrorMessage;
  bool _permissionDenied = false;

  // Stamp settings
  StampSettings _stampSettings = StampSettings();
  String _currentAddress =
      ''; // '' = not resolved/unavailable (footer then says so)

  // Controls state
  bool _isTorchOn = false;
  double _currentZoom = 1.0;
  double _maxZoom = 1.0;
  bool _isVideoMode = false;
  bool _isRecordingVideo = false;

  // Live GPS state
  Position? _currentPosition;
  bool _isLoadingGps = false;

  // Captured media and stamp
  XFile? _capturedFile;
  GeoCamStamp? _stamp;
  GeoCamRecord? _savedRecord;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isInitializing = false;
    } else {
      _initCamera();
      _fetchLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      cameraController.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingGps = true);
    final pos = await GeoCamVerificationService.instance
        .getCurrentLocation()
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLoadingGps = false;
      });
    }
    // Resolve the street address in the background so the shutter is never delayed by it.
    final resolved = await GeoCamVerificationService.instance.resolveAddress(
      pos,
    );
    if (mounted && identical(_currentPosition, pos)) {
      setState(() => _currentAddress = resolved);
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _cameraErrorMessage = null;
      _permissionDenied = false;
    });

    try {
      _availableCameras = await availableCameras().timeout(
        const Duration(milliseconds: 2500),
      );
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
        return;
      }

      final camera =
          _availableCameras[_selectedCameraIndex % _availableCameras.length];
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await controller.initialize().timeout(const Duration(seconds: 4));
      double maxZ = 1.0;
      try {
        maxZ = await controller.getMaxZoomLevel();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _controller = controller;
          _maxZoom = maxZ;
          _currentZoom = 1.0;
          _isTorchOn = false;
          _isInitializing = false;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          if (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt') {
            _permissionDenied = true;
            _cameraErrorMessage = 'Camera permission was denied. Please allow camera access in app settings.';
          } else {
            _cameraErrorMessage =
                'Camera initialization failed: ${e.description ?? e.code}';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) return;
    setState(() {
      _selectedCameraIndex =
          (_selectedCameraIndex + 1) % _availableCameras.length;
    });
    await _controller?.dispose();
    _controller = null;
    await _initCamera();
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final next = !_isTorchOn;
      await _controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _isTorchOn = next);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Torch/Flash is not available on this lens.'),
          ),
        );
      }
    }
  }

  Future<void> _toggleZoom() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final target = _currentZoom == 1.0
          ? (_maxZoom >= 2.0 ? 2.0 : _maxZoom)
          : 1.0;
      await _controller!.setZoomLevel(target);
      if (mounted) {
        setState(() => _currentZoom = target);
      }
    } catch (_) {}
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isRecordingVideo)
      return;
    try {
      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecordingVideo = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Could not start video: $e'),
          ),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_isRecordingVideo)
      return;
    try {
      setState(() => _isCapturing = true);
      final file = await _controller!.stopVideoRecording();
      final bytes = await file.readAsBytes();

      final stamp = await GeoCamVerificationService.instance.createVideoStamp(
        videoBytes: bytes,
        position: _currentPosition,
        address: _currentAddress,
      );

      GeoCamRecord? savedRecord;
      try {
        savedRecord = await GeoCamHistoryStore.saveVideo(
          id: stamp.recordId,
          videoPath: file.path,
          qrPayload: stamp.qrPayload,
          timestamp: stamp.timestamp,
          latitude: stamp.latitude,
          longitude: stamp.longitude,
          accuracy: stamp.accuracy,
          altitude: stamp.altitude,
          address: stamp.address,
          sha256: stamp.sha256,
          signature: stamp.signature,
          publicKey: stamp.publicKey,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _capturedFile = file;
          _stamp = stamp;
          _savedRecord = savedRecord;
          _isRecordingVideo = false;
          _isCapturing = false;
        });
        if (savedRecord != null) _autoSyncAfterCapture(savedRecord.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingVideo = false;
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to record video: $e'),
          ),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing)
      return;

    try {
      setState(() => _isCapturing = true);
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();

      final stamp = await GeoCamVerificationService.instance.createStamp(
        imageBytes: bytes,
        position: _currentPosition,
        address: _currentAddress,
        settings: _stampSettings,
      );

      final finalBytes = stamp.stampedBytes ?? bytes;
      if (stamp.stampedBytes != null) {
        try {
          await File(file.path).writeAsBytes(finalBytes, flush: true);
        } catch (_) {}
      }

      // Persist to local GeoCam history store with Ed25519 cryptographic signature and QR payload
      GeoCamRecord? savedRecord;
      try {
        savedRecord = await GeoCamHistoryStore.save(
          id: stamp.recordId,
          imageBytes: finalBytes,
          qrPayload: stamp.qrPayload,
          timestamp: stamp.timestamp,
          latitude: stamp.latitude,
          longitude: stamp.longitude,
          accuracy: stamp.accuracy,
          altitude: stamp.altitude,
          address: stamp.address,
          sha256: stamp.sha256,
          signature: stamp.signature,
          publicKey: stamp.publicKey,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _capturedFile = file;
          _stamp = stamp;
          _savedRecord = savedRecord;
          _isCapturing = false;
        });
        if (savedRecord != null) _autoSyncAfterCapture(savedRecord.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to capture photo: $e'),
          ),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedFile = null;
      _stamp = null;
      _savedRecord = null;
      _isSyncingCaptured = false;
      _capturedSynced = false;
      _capturedSyncMessage = null;
    });
    _fetchLocation();
  }

  /// Saves-first, uploads-after: the capture is already stored locally; this uploads it in the background
  /// (retrying later if offline) and reflects the server-confirmed state on screen.
  void _autoSyncAfterCapture(String recordId) {
    setState(() => _isSyncingCaptured = true);
    GeoCamAutoSync.instance.syncSoon().whenComplete(() async {
      final r = await GeoCamHistoryStore.getById(recordId);
      if (!mounted || _stamp?.recordId != recordId) return;
      setState(() {
        _isSyncingCaptured = false;
        if (r != null) _savedRecord = r;
        _capturedSynced = r?.isSynchronized ?? false;
        _capturedSyncMessage = _capturedSynced
            ? null
            : (r?.isSyncFailed ?? false)
            ? 'Upload failed: ${r?.syncError ?? 'unknown error'}. It is saved on this device and will be retried automatically.'
            : null;
      });
    });
  }

  Future<void> _shareCapturedMedia() async {
    if (_capturedFile == null || _stamp == null) return;

    final isSynced = _capturedSynced || (_savedRecord?.isSynchronized ?? false);
    if (!isSynced && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
          content: Text(
            'Sharing original stamped media. Note: Web verification URL will show '
            '"Not Found" until you synchronize this capture online.',
          ),
        ),
      );
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_capturedFile!.path)],
          text:
              'CampusOS GeoCam Verified Capture\n'
              'Record ID: ${_stamp!.recordId}\n'
              'Verification URL: ${_stamp!.qrPayload}\n'
              'SHA-256: ${_stamp!.sha256}',
          subject: 'CampusOS GeoCam Evidence ${_stamp!.recordId}',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to share: $e'),
          ),
        );
      }
    }
  }

  Future<void> _saveCapturedToGalleryRetry() async {
    if (_savedRecord == null) return;
    try {
      final success = await GeoCamHistoryStore.saveToGallery(_savedRecord!);
      final updated = await GeoCamHistoryStore.getById(_savedRecord!.id);
      if (mounted) {
        setState(() {
          if (updated != null) _savedRecord = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: success ? AppColors.success : AppColors.error,
            content: Text(
              success
                  ? 'Saved to phone Gallery in "CampusOS GeoCam"'
                  : 'Failed to save to gallery: ${_savedRecord?.galleryError ?? "Unknown error"}',
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

  Future<void> _syncCapturedOnline() async {
    if (_stamp == null || _capturedFile == null) return;
    final confirmed = await showGeoCamSyncDisclosureDialog(
      context,
      recordId: _stamp!.recordId,
      mediaType: _capturedFile!.path.endsWith('.mp4') ? 'video' : 'photo',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSyncingCaptured = true);
    final record = await GeoCamHistoryStore.getById(_stamp!.recordId);
    if (record == null) {
      if (mounted) {
        setState(() => _isSyncingCaptured = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Could not find saved capture in local storage.'),
          ),
        );
      }
      return;
    }

    final res = await GeoCamSyncService.instance.syncRecord(record);
    if (mounted) {
      setState(() {
        _isSyncingCaptured = false;
        _capturedSynced = res.success;
        _capturedSyncMessage = res.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: res.success ? AppColors.success : AppColors.error,
          content: Text(res.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GeoCam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Stamp Settings',
            onPressed: () {
              showGeoCamSettingsSheet(
                context,
                initialSettings: _stampSettings,
                onSettingsChanged: (s) => setState(() => _stampSettings = s),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Verify QR / Record',
            onPressed: () {
              showGeoCamVerificationDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Capture History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GeoCamHistoryScreen()),
              );
            },
          ),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_capturedFile != null && _stamp != null) {
      return _buildCapturedView();
    }

    if (_isInitializing) {
      return const LoadingView(message: 'Initializing device camera & GPS...');
    }

    if (_permissionDenied) {
      return _buildErrorOrPermissionView();
    }

    if (_controller != null && _controller!.value.isInitialized) {
      return _buildLiveCameraView();
    }

    return _buildFallbackView();
  }

  Widget _buildLiveCameraView() {
    return Stack(
      children: [
        // Camera viewfinder filling available space
        Positioned.fill(child: CameraPreview(_controller!)),

        // Top Status HUD (GPS, Camera Switch, Flash)
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GPS indicator & stamp chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentPosition != null
                          ? Icons.location_on
                          : Icons.location_searching,
                      color: _currentPosition != null
                          ? Colors.greenAccent
                          : Colors.amberAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPosition != null
                            ? '${_currentPosition!.latitude.toStringAsFixed(4)}° N, ${_currentPosition!.longitude.toStringAsFixed(4)}° E (±${_currentPosition!.accuracy.toStringAsFixed(1)}m)'
                            : (_isLoadingGps
                                  ? 'Locking GPS satellite signal...'
                                  : 'GPS coordinates unavailable'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_maxZoom > 1.0)
                      GestureDetector(
                        onTap: _toggleZoom,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_currentZoom.toStringAsFixed(1)}x',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? Colors.amberAccent : Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Toggle Flash/Torch',
                      onPressed: _toggleTorch,
                    ),
                    if (_availableCameras.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_android,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Switch Camera',
                        onPressed: _switchCamera,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Center viewfinder framing guide
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white38, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.filter_center_focus_rounded,
                color: Colors.white30,
                size: 56,
              ),
            ),
          ),
        ),

        // Bottom Capture Controls
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Security stamp tag or recording indicator
              if (_isRecordingVideo)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'RECORDING VIDEO • CRYPTO HASHING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.accent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'CRYPTO-STAMP READY • SHA-256',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Mode Switcher (PHOTO / VIDEO)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!_isRecordingVideo)
                          setState(() => _isVideoMode = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: !_isVideoMode
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'PHOTO',
                          style: TextStyle(
                            color: !_isVideoMode
                                ? Colors.white
                                : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (!_isRecordingVideo)
                          setState(() => _isVideoMode = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isVideoMode
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'VIDEO',
                          style: TextStyle(
                            color: _isVideoMode ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Capture shutter button
              GestureDetector(
                onTap: _isCapturing
                    ? null
                    : (_isVideoMode
                          ? (_isRecordingVideo
                                ? _stopVideoRecording
                                : _startVideoRecording)
                          : _capturePhoto),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isCapturing
                        ? AppColors.accent
                        : (_isVideoMode
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: _isCapturing
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : (_isVideoMode
                              ? (_isRecordingVideo
                                    ? Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 58,
                                        height: 58,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                        ),
                                      ))
                              : Container(
                                  width: 58,
                                  height: 58,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                )),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedView() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Photo preview card
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_capturedFile!.path.endsWith('.mp4'))
                Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 64,
                          color: Colors.white70,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Recorded Video MP4',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Image.file(File(_capturedFile!.path), fit: BoxFit.contain),
              // Verified Watermark Banner
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _capturedFile!.path.endsWith('.mp4')
                            ? 'VIDEO RECORDED & STAMPED'
                            : 'PHOTO CAPTURED & STAMPED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Verification Metadata Card
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
                  const Text(
                    'Verification Stamp',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  StatusBadge.status(_stamp!.status),
                ],
              ),
              const Divider(height: 20),
              _buildMetaRow('Record ID', _stamp!.recordId),
              _buildMetaRow(
                'Capture Time',
                _stamp!.timestamp.toIso8601String(),
              ),
              _buildMetaRow('GPS Location', _stamp!.formattedCoordinates),
              _buildMetaRow('Accuracy', _stamp!.formattedAccuracy),
              _buildMetaRow('SHA-256 Digest', _stamp!.sha256, isHash: true),
              if (_stamp!.signature.isNotEmpty)
                _buildMetaRow(
                  'Ed25519 Signature',
                  '${_stamp!.signature.substring(0, 24)}...',
                  isHash: true,
                ),
              if (_stamp!.publicKey.isNotEmpty)
                _buildMetaRow(
                  'Device Public Key',
                  '${_stamp!.publicKey.substring(0, 24)}...',
                  isHash: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // QR Code & Verification Card
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
                      'GeoCam Verification QR',
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
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'SCANNABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                      data: _stamp!.qrPayload,
                      version: QrVersions.auto,
                      size: 100,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verifiable Payload URL:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _stamp!.qrPayload,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            showGeoCamVerificationDialog(
                              context,
                              initialRecordId: _stamp!.recordId,
                            );
                          },
                          icon: const Icon(Icons.verified_outlined, size: 16),
                          label: const Text(
                            'Verify QR Now',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 34),
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
        const SizedBox(height: AppSpacing.md),

        // Online Web Verification & Synchronization Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _capturedSynced ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _capturedSynced
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
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
                        _capturedSynced
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_upload_outlined,
                        color: _capturedSynced
                            ? AppColors.success
                            : AppColors.accent,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _capturedSynced
                          ? AppColors.success.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _capturedSynced
                          ? 'SYNCHRONIZED'
                          : _isSyncingCaptured
                          ? 'SYNCING'
                          : (_savedRecord?.isSyncFailed ?? false)
                          ? 'FAILED'
                          : 'PENDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _capturedSynced
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _capturedSynced
                    ? (_capturedSyncMessage ??
                          'Successfully synchronized to https://geocam-server.onrender.com. Anyone scanning the QR code can now verify this capture in their web browser.')
                    : (_capturedSyncMessage ??
                          'Saved on your device (QR and photo work offline). It uploads automatically as soon as the GeoCam server is reachable; until then scanning the QR reports "not found".'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              if (!_capturedSynced)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSyncingCaptured ? null : _syncCapturedOnline,
                    icon: _isSyncingCaptured
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
                      _isSyncingCaptured
                          ? 'Synchronizing...'
                          : ((_savedRecord?.isSyncFailed ?? false)
                                ? 'Retry upload now'
                                : 'Upload now'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Ready for remote web inspection.',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isSyncingCaptured
                          ? null
                          : _syncCapturedOnline,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Re-sync'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Public Phone Gallery Save Status Card
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
                    (_savedRecord?.isSavedToGallery ?? false)
                        ? Icons.photo_library_rounded
                        : Icons.photo_library_outlined,
                    color: (_savedRecord?.isSavedToGallery ?? false)
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
                      color: (_savedRecord?.isSavedToGallery ?? false)
                          ? AppColors.success.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (_savedRecord?.isSavedToGallery ?? false)
                          ? 'IN GALLERY'
                          : 'LOCAL ONLY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: (_savedRecord?.isSavedToGallery ?? false)
                            ? AppColors.success
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (_savedRecord?.isSavedToGallery ?? false)
                    ? 'Saved directly to your device Photos under the "CampusOS GeoCam" album.'
                    : (_savedRecord?.galleryError != null
                          ? 'Gallery save error: ${_savedRecord!.galleryError}'
                          : 'Capture is preserved in CampusOS. Tap below to save to your public Gallery album.'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (!(_savedRecord?.isSavedToGallery ?? false)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _saveCapturedToGalleryRetry,
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
        const SizedBox(height: AppSpacing.md),

        // Attendance Integration Notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB3DFE4)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primaryLight,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance Integration: Presence in CampusOS is automatically recorded '
                  'by scheduled classroom AI recognition cameras. Self-service photo submission '
                  'is recorded and tamper-proof stamped for manual verification.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0B1B3A),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Action Buttons: Retake / Share / History / Attendance
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retakePhoto,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retake', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareCapturedMedia,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GeoCamHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('History', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AttendanceScreen()),
              );
            },
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Go to Smart Attendance'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isHash = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: isHash ? 'monospace' : null,
                color: isHash ? AppColors.accent : AppColors.textPrimary,
                fontWeight: isHash ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOrPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Camera Access Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _cameraErrorMessage ?? 'Camera permission is needed to capture and verify attendance photos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_permissionDenied)
              ElevatedButton.icon(
                onPressed: () => Geolocator.openAppSettings(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open App Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(200, 48),
                ),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initCamera,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Initialization'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackView() {
    // Graceful fallback for test/mock environments where no camera hardware is present
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.glassFillStrong,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primaryLight),
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
                        StatusBadge.status(
                          _currentPosition != null ? 'READY' : 'NO GPS FIX',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentPosition != null
                          ? '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'
                          : 'Location unavailable',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Text(
                      'SIMULATION MODE: no camera available; previews use sample image data, not a real capture.',
                      style: TextStyle(
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
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isVideoMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: !_isVideoMode
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'PHOTO',
                      style: TextStyle(
                        color: !_isVideoMode
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isVideoMode = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isVideoMode ? Colors.red : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'VIDEO',
                      style: TextStyle(
                        color: _isVideoMode
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton.icon(
          onPressed: () async {
            final stamp = await GeoCamVerificationService.instance.createStamp(
              imageBytes: Uint8List.fromList([1, 2, 3, 4]),
              position: _currentPosition,
            );
            if (mounted) {
              setState(() {
                _capturedFile = XFile('');
                _stamp = stamp;
              });
            }
          },
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text('Simulate Geo-Stamp Preview (sample data)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }
}
