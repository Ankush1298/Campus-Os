import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _urlController;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiClient.baseUrl);
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;

    if (id.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both ID and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.instance.login(id: id, password: password);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException ? e.message : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleDemoLogin(UserSession demoSession) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    AuthService.instance.loginDemo(demoSession);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo & Title
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hub_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'CampusOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unified Smart Campus Operating System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Login Card Container
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign In to Your Campus Portal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ID Input
                        TextField(
                          controller: _idController,
                          decoration: const InputDecoration(
                            labelText: 'Roll No / Faculty ID',
                            hintText: 'e.g. 22CS1042 or FAC-CS-08',
                            prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Password Input
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your account password',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Log In'),
                        ),

                        // Server config expander
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() => _showServerConfig = !_showServerConfig);
                            },
                            icon: Icon(
                              _showServerConfig ? Icons.expand_less : Icons.settings_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            label: Text(
                              _showServerConfig ? 'Hide Server Settings' : 'Configure Backend URL',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ),

                        if (_showServerConfig) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'API Base URL',
                              hintText: 'http://10.0.2.2:8000',
                              helperText: 'Emulator: http://10.0.2.2:8000 • Device: host LAN IP',
                              prefixIcon: Icon(Icons.dns_outlined, size: 18),
                            ),
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            onChanged: (val) => AuthService.instance.saveBackendUrl(val),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Quick Demo Mode Switcher
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, color: AppColors.warning, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Instant Demo Access',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _handleDemoLogin(UserSession.demoStudent()),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text(
                                  'Student',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _handleDemoLogin(UserSession.demoFaculty()),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text(
                                  'Faculty',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _handleDemoLogin(UserSession.demoAdmin()),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
