import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../models/user_session.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal() {
    ApiClient.onUnauthorized = (exception) {
      debugPrint(
        'AuthService: Session unauthorized or expired (${exception.statusCode}). Terminating session.',
      );
      handleSessionExpired();
    };
  }

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ValueNotifier<UserSession?> currentSession =
      ValueNotifier<UserSession?>(null);

  static const String _sessionKey = 'campusos_active_session';
  static const String _urlKey = 'campusos_backend_base_url';

  Future<void> initialize() async {
    try {
      // 1. Restore persisted base URL if previously configured
      final savedUrl = await _storage.read(key: _urlKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        ApiClient.setBaseUrl(savedUrl);
      }

      // 2. Restore active session if valid
      final jsonStr = await _storage.read(key: _sessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr);
        final session = UserSession.fromJson(data);

        // Immediately discard expired sessions
        if (session.isExpired) {
          debugPrint(
            'AuthService: Stored session for ${session.id} is expired. Purging.',
          );
          await _storage.delete(key: _sessionKey);
          return;
        }

        ApiClient.setAuthToken(session.token);
        ApiClient.setErpToken(session.erpToken);
        currentSession.value = session;
      }
    } catch (e) {
      debugPrint('AuthService: Failed to restore session: $e');
    }
  }

  Future<void> saveBackendUrl(String url) async {
    ApiClient.setBaseUrl(url);
    try {
      await _storage.write(key: _urlKey, value: ApiClient.baseUrl);
    } catch (e) {
      debugPrint('AuthService: Failed to persist backend URL: $e');
    }
  }

  Future<UserSession> login({
    required String id,
    required String password,
  }) async {
    final response = await ApiClient.post('/api/auth/login', {
      'id': id.trim(),
      'password': password,
    });

    var session = UserSession.fromJson(response);
    // If a separate ERP server is configured, sign in there too with the same credentials.
    // Best effort: if it rejects or is unreachable, ERP simply reports "unavailable".
    if (ApiClient.erpUrl.trim().isNotEmpty) {
      try {
        final erp = await ApiClient.post('/api/auth/login', {
          'id': id.trim(),
          'password': password,
        }, erp: true);
        session = session.withErpToken(erp['token'] as String?);
      } on ApiException catch (e) {
        debugPrint('AuthService: ERP login unavailable (${e.statusCode}).');
      }
    }
    await _persistSession(session);
    return session;
  }

  Future<UserSession> loginDemo(UserSession session) async {
    await _persistSession(session);
    return session;
  }

  Future<void> _persistSession(UserSession session) async {
    ApiClient.setAuthToken(session.token);
    ApiClient.setErpToken(session.erpToken);
    currentSession.value = session;
    try {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (e) {
      debugPrint('AuthService: Failed to securely write session: $e');
    }
  }

  Future<void> handleSessionExpired() async {
    ApiClient.setAuthToken(null);
    ApiClient.setErpToken(null);
    currentSession.value = null;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('AuthService: Failed to delete session key: $e');
    }
  }

  Future<void> logout() async {
    await handleSessionExpired();
  }
}
