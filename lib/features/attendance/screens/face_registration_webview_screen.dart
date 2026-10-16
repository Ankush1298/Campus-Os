import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_session.dart';

class FaceRegistrationWebViewScreen extends StatefulWidget {
  final String url;
  final UserSession session;

  static const String approvedHost =
      'attendance-register-production.up.railway.app';

  /// Evaluates whether a given URL string safely matches the approved HTTPS registration origin
  static bool isApprovedUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.toLowerCase() != approvedHost) return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.hasPort && uri.port != 443) return false;
    return true;
  }

  const FaceRegistrationWebViewScreen({
    super.key,
    required this.url,
    required this.session,
  });

  @override
  State<FaceRegistrationWebViewScreen> createState() =>
      _FaceRegistrationWebViewScreenState();
}

class _FaceRegistrationWebViewScreenState
    extends State<FaceRegistrationWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    // Fail immediately if the initial target URL fails trusted-origin validation
    if (!FaceRegistrationWebViewScreen.isApprovedUrl(widget.url)) {
      _isLoading = false;
      _errorMessage = 'Untrusted registration URL rejected: ${widget.url}';
      return;
    }

    final WebViewController controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B1B3A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (FaceRegistrationWebViewScreen.isApprovedUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            debugPrint(
              'Blocked unapproved WebView navigation attempt: ${request.url}',
            );
            return NavigationDecision.prevent;
          },
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress);
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            if (FaceRegistrationWebViewScreen.isApprovedUrl(url)) {
              _injectPreFillScript();
            } else {
              debugPrint('Suppressed prefill on unapproved URL: $url');
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
        ),
      );

    // Grant WebRTC camera/microphone permissions natively only for the approved host
    if (!kIsWeb && controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setOnPlatformPermissionRequest((request) async {
        final currentUrl = await controller.currentUrl();
        final isApprovedOrigin = FaceRegistrationWebViewScreen.isApprovedUrl(
          currentUrl,
        );

        if (!isApprovedOrigin) {
          debugPrint(
            'Denied WebRTC permission request for unapproved origin: $currentUrl',
          );
          await request.deny();
          return;
        }

        // Restrict strictly to camera media stream only; deny microphone and any other resource
        final isCameraOnly =
            request.types.length == 1 &&
            request.types.first == WebViewPermissionResourceType.camera;

        if (!isCameraOnly) {
          debugPrint(
            'Denied unapproved permission resource types: ${request.types}',
          );
          await request.deny();
          return;
        }

        await request.grant();
      });
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadRequest(Uri.parse(widget.url));
    _controller = controller;
  }

  Future<void> _injectPreFillScript() async {
    final c = _controller;
    if (c == null) return;
    final currentUrl = await c.currentUrl();
    if (!FaceRegistrationWebViewScreen.isApprovedUrl(currentUrl)) {
      debugPrint(
        'Skipped prefill injection: not on approved host ($currentUrl)',
      );
      return;
    }

    // Safely pre-fill student/faculty ID and name via strict JSON encoding without passing tokens or passcodes
    final safeId = jsonEncode(widget.session.id);
    final safeName = jsonEncode(widget.session.name);
    final js =
        '''
      (function() {
        try {
          var rInput = document.getElementById('rollInput');
          if (rInput && typeof rInput.value === 'string' && !rInput.value.trim()) {
            rInput.value = $safeId;
            rInput.dispatchEvent(new Event('input', { bubbles: true }));
            rInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
          var nInput = document.getElementById('nameInput');
          if (nInput && typeof nInput.value === 'string' && !nInput.value.trim()) {
            nInput.value = $safeName;
            nInput.dispatchEvent(new Event('input', { bubbles: true }));
            nInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
        } catch(e) {
          console.warn('KYC prefill suppressed:', e);
        }
      })();
    ''';
    c.runJavaScript(js).catchError((e) {
      debugPrint('Prefill injection error: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final c = _controller;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1B3A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B2B4B),
          foregroundColor: Colors.white,
          title: Text(
            '${widget.session.isTeacher ? 'Faculty' : 'Student'} Biometric KYC',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reload KYC Page',
              onPressed: _controller == null
                  ? null
                  : () => _controller!.reload(),
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: Colors.transparent,
                    color: AppColors.accent,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_errorMessage != null)
              Container(
                color: const Color(0xFF0B1B3A),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load Face Registration service',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          if (_controller != null) {
                            _controller!.reload();
                          } else {
                            _initWebView();
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Connection'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
