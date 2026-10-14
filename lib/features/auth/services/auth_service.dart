import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';
import '../models/user_session.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ValueNotifier<UserSession?> currentSession = ValueNotifier<UserSession?>(null);

  static const String _sessionKey = 'campusos_active_session';

  Future<void> initialize() async {
    try {
      final jsonStr = await _storage.read(key: _sessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr);
        final session = UserSession.fromJson(data);
        ApiClient.setAuthToken(session.token);
        currentSession.value = session;
      }
    } catch (e) {
      debugPrint('AuthService: Failed to restore session: $e');
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

    final session = UserSession.fromJson(response);
    await _persistSession(session);
    return session;
  }

  Future<UserSession> loginDemo(UserSession session) async {
    await _persistSession(session);
    return session;
  }

  Future<void> _persistSession(UserSession session) async {
    ApiClient.setAuthToken(session.token);
    currentSession.value = session;
    try {
      await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('AuthService: Failed to securely write session: $e');
    }
  }

  Future<void> logout() async {
    ApiClient.setAuthToken(null);
    currentSession.value = null;
    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('AuthService: Failed to delete session key: $e');
    }
  }
}
