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
  // Default base URL for Attendance backend - configurable at runtime
  static String baseUrl = 'http://10.0.2.2:8000'; // Standard Android emulator localhost

  static String? _authToken;

  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
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
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 8));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Unable to connect to backend server ($baseUrl). Please check network or enable Demo Mode.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: e.toString());
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'Unable to connect to backend server ($baseUrl). Please check network or enable Demo Mode.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: e.toString());
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

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      details: decoded,
    );
  }
}
