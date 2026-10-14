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
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String baseUrl = defaultUrl;
  static String? _authToken;
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
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  static Map<String, String> _headers() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final uri = _parseUri(path);
    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 8));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Unable to connect to Attendance server at $baseUrl. Ensure server is running and accessible on this network.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Connection timed out while reaching Attendance server at $baseUrl.',
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

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final uri = _parseUri(path);
    try {
      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Unable to connect to Attendance server at $baseUrl. Ensure server is running and accessible on this network.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Connection timed out while reaching Attendance server at $baseUrl.',
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

  static Uri _parseUri(String path) {
    try {
      final uri = Uri.parse('$baseUrl$path');
      if (!uri.hasScheme || uri.host.isEmpty) {
        throw ApiException(
          statusCode: 0,
          message: 'Invalid backend URL format: "$baseUrl". Must include a valid host and port (e.g. http://10.0.2.2:8000).',
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

  static Map<String, dynamic> _handleResponse(http.Response response) {
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
      } else if (decoded['error'] is Map && decoded['error']['message'] != null) {
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

    if ((response.statusCode == 401 || response.statusCode == 403) && _authToken != null) {
      onUnauthorized?.call(exception);
    }

    throw exception;
  }
}
