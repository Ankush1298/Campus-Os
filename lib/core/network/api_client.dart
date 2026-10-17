import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({required this.statusCode, required this.message, this.details});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  // Configurable at build time via --dart-define=API_BASE_URL=http://...
  static const String defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://attendance-app-production-578c.up.railway.app',
  );

  // Separate CampusOS ERP/leave server (server/server.py). Empty = same server as baseUrl.
  static const String erpUrl = String.fromEnvironment('ERP_API_BASE_URL');

  static String baseUrl = defaultUrl;
  static String? _authToken;
  static String? _erpToken;

  static String get erpBaseUrl =>
      erpUrl.trim().isEmpty ? baseUrl : normalizeUrl(erpUrl);
  static bool get hasErpToken => _effectiveErpToken?.isNotEmpty ?? false;

  // Never send the Attendance token to a different (ERP) host.
  static String? get _effectiveErpToken =>
      erpUrl.trim().isEmpty ? (_erpToken ?? _authToken) : _erpToken;

  static void setErpToken(String? token) {
    _erpToken = token;
  }

  static void Function(ApiException)? onUnauthorized;

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static void setBaseUrl(String url) {
    baseUrl = normalizeUrl(url);
  }

  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return defaultUrl;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static Map<String, String> _headers({bool erp = false, String? tokenOverride}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = tokenOverride ?? (erp ? _effectiveErpToken : _authToken);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool erp = false,
  }) async {
    final uri = _parseUri(path, erp: erp);
    try {
      final response = await http
          .get(uri, headers: _headers(erp: erp))
          .timeout(const Duration(seconds: 8));
      return _handleResponse(response, erp: erp);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message:
            'Unable to connect to ${erp ? 'ERP' : 'Attendance'} server at ${erp ? erpBaseUrl : baseUrl}. Ensure server is running and accessible on this network.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message:
            'Connection timed out while reaching Attendance server at $baseUrl.',
      );
    } on HandshakeException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'SSL/TLS handshake failed for $baseUrl: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: e.toString());
    }
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool erp = false,
    Duration timeout = const Duration(seconds: 10),
    String? token,
  }) async {
    final uri = _parseUri(path, erp: erp);
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(erp: erp, tokenOverride: token),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _handleResponse(response, erp: erp);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message:
            'Unable to connect to ${erp ? 'ERP' : 'Attendance'} server at ${erp ? erpBaseUrl : baseUrl}. Ensure server is running and accessible on this network.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message:
            'Connection timed out while reaching Attendance server at $baseUrl.',
      );
    } on HandshakeException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'SSL/TLS handshake failed for $baseUrl: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: e.toString());
    }
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool erp = false,
  }) async {
    final uri = _parseUri(path, erp: erp);
    try {
      final response = await http
          .put(
            uri,
            headers: _headers(erp: erp),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response, erp: erp);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message:
            'Unable to connect to ${erp ? 'ERP' : 'Attendance'} server at ${erp ? erpBaseUrl : baseUrl}. Ensure server is running and accessible on this network.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message:
            'Connection timed out while reaching Attendance server at $baseUrl.',
      );
    } on HandshakeException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'SSL/TLS handshake failed for $baseUrl: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: e.toString());
    }
  }

  /// Multipart file upload (used for the timetable OCR upload).
  static Future<Map<String, dynamic>> postFile(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    bool erp = false,
  }) async {
    final uri = _parseUri(path, erp: erp);
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_headers(erp: erp)..remove('Content-Type'))
        ..files.add(
          http.MultipartFile.fromBytes(field, bytes, filename: filename),
        );
      final streamed = await request.send().timeout(
        const Duration(seconds: 90),
      );
      return _handleResponse(
        await http.Response.fromStream(streamed),
        erp: erp,
      );
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Unable to connect to the server while uploading.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Upload timed out. Scanned timetables can take a minute; try again.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: e.toString());
    }
  }

  static Uri _parseUri(String path, {bool erp = false}) {
    final baseUrl = erp ? erpBaseUrl : ApiClient.baseUrl;
    try {
      final uri = Uri.parse('$baseUrl$path');
      if (!uri.hasScheme || uri.host.isEmpty) {
        throw ApiException(
          statusCode: 0,
          message:
              'Invalid backend URL format: "$baseUrl". Must include a valid host and port (e.g. http://10.0.2.2:8000).',
        );
      }
      return uri;
    } on FormatException {
      throw ApiException(
        statusCode: 0,
        message: 'Malformed backend URL: "$baseUrl$path".',
      );
    }
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    bool erp = false,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }

    String errorMessage = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      if (decoded['detail'] != null) {
        errorMessage = decoded['detail'].toString();
      } else if (decoded['error'] is Map &&
          decoded['error']['message'] != null) {
        errorMessage = decoded['error']['message'].toString();
      } else if (decoded['message'] != null) {
        errorMessage = decoded['message'].toString();
      }
    }

    final exception = ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      details: decoded,
    );

    // Only a 401 on the primary backend means the session is gone; 403 is a permission error and
    // ERP-server rejections must not log the user out of the whole app.
    if (response.statusCode == 401 && !erp && _authToken != null) {
      onUnauthorized?.call(exception);
    }

    throw exception;
  }
}
