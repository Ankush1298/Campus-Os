import 'package:flutter/material.dart';

import '../../../core/branding/campus_logo.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
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
  final _passwordFocus = FocusNode();
  late final TextEditingController _urlController;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _submitted = false;
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
    _passwordFocus.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;

    if (id.isEmpty || password.isEmpty) {
      setState(() {
        _submitted = true;
        _errorMessage = 'Please enter both ID and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _submitted = false;
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.md * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      const Center(
                        child: CampusLogo(markSize: 64, stacked: true),
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      const Text(
                        'Attendance, leave, capture and practical learning, in one campus app.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySecondary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _signInCard(),
                      const SizedBox(height: AppSpacing.md),
                      _demoCard(),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _signInCard() {
    return GlassCard(
      blur: true,
      tone: GlassTone.strong,
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sign In to Your Campus Portal', style: AppText.title),
            const SizedBox(height: 4),
            const Text(
              'Use the ID and password issued by your institution.',
              style: AppText.meta,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_errorMessage != null) ...[
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9E1C27),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _idController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: 'Roll No / Faculty ID',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                errorText: _submitted && _idController.text.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !_isLoading,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                errorText: _submitted && _passwordController.text.isEmpty
                    ? 'Required'
                    : null,
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.fast),
                child: _isLoading
                    ? const SizedBox(
                        key: ValueKey('busy'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Log In', key: ValueKey('idle')),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showServerConfig = !_showServerConfig),
                icon: Icon(
                  _showServerConfig
                      ? Icons.expand_less_rounded
                      : Icons.settings_outlined,
                  size: 18,
                ),
                label: Text(
                  _showServerConfig
                      ? 'Hide Server Settings'
                      : 'Configure Backend URL',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.of(context),
              curve: AppMotion.curve,
              child: _showServerConfig
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'https://your-attendance-server',
                          helperText: 'Attendance server. Emulator: http://10.0.2.2:8000',
                          helperMaxLines: 2,
                          prefixIcon: Icon(Icons.dns_outlined, size: 18),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        onChanged: (val) =>
                            AuthService.instance.saveBackendUrl(val),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoCard() {
    return GlassCard(
      tint: AppColors.accentLight,
      tone: GlassTone.tinted,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.warning, size: 18),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Instant Demo Access',
                  style: AppText.heading,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Explore with sample data on this device. Nothing is sent to a server.',
            textAlign: TextAlign.center,
            style: AppText.meta,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _demoButton('Student', UserSession.demoStudent)),
              const SizedBox(width: 8),
              Expanded(child: _demoButton('Faculty', UserSession.demoFaculty)),
              const SizedBox(width: 8),
              Expanded(child: _demoButton('Admin', UserSession.demoAdmin)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _demoButton(String label, UserSession Function() make) =>
      OutlinedButton(
        onPressed: _isLoading ? null : () => _handleDemoLogin(make()),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      );
}
