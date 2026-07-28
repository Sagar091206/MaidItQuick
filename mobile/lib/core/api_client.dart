import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

/// A small API wrapper used by the mobile MVP.
///
/// It logs request paths and response codes only in debug builds. Session
/// tokens and passwords are intentionally never written to Logcat.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<dynamic> get(String path, {String? token}) async {
    final url = _url(path);
    _logRequest('GET', url);
    final response = await _client.get(url, headers: _headers(token));
    return _decode(response, 'GET', url);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final url = _url(path);
    _logRequest('POST', url);
    final response = await _client.post(
      url,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response, 'POST', url);
  }

  Future<dynamic> multipartPost(
    String path, {
    required String token,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final url = _url(path);
    _logRequest('POST multipart', url);
    final request = http.MultipartRequest('POST', url)
      ..headers.addAll({'Authorization': 'Bearer $token'})
      ..files.add(
        http.MultipartFile.fromBytes(
          'document',
          bytes,
          filename: fileName,
          contentType: _mediaType(mimeType),
        ),
      );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response, 'POST multipart', url);
  }

  Uri _url(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  dynamic _decode(http.Response response, String method, Uri url) {
    _logResponse(method, url, response.statusCode);
    dynamic payload;
    if (response.body.isEmpty) {
      payload = <String, dynamic>{};
    } else {
      try {
        payload = jsonDecode(response.body);
      } on FormatException {
        payload = <String, dynamic>{'message': response.body};
      }
    }
    if (response.statusCode >= 400) {
      final message = payload is Map ? payload['message']?.toString() : null;
      throw ApiException(message ?? 'Request failed (${response.statusCode})', response.statusCode);
    }
    return payload;
  }

  void _logRequest(String method, Uri url) {
    if (kDebugMode) debugPrint('[MaidItQuick API] -> $method $url');
  }

  void _logResponse(String method, Uri url, int statusCode) {
    if (kDebugMode) debugPrint('[MaidItQuick API] <- $statusCode $method $url');
  }
}

MediaType _mediaType(String mimeType) {
  final parts = mimeType.split('/');
  if (parts.length == 2) return MediaType(parts[0], parts[1]);
  return MediaType('application', 'octet-stream');
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
