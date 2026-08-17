import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

/// A small API wrapper used by the mobile MVP.
///
/// It logs request paths and response codes only in debug builds. Session
/// tokens and passwords are intentionally never written to logs.
class ApiClient {
  ApiClient({http.Client? client, this.onSessionExpired})
      : _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 30);

  /// Invoked once per session when an authenticated request comes back 401.
  /// Used to force a clean local logout instead of leaving dead sessions.
  void Function()? onSessionExpired;

  final http.Client _client;

  Future<dynamic> get(String path, {String? token}) async {
    final url = _url(path);
    _logRequest('GET', url);
    final response =
        await _send(() => _client.get(url, headers: _headers(token)), url);
    return _decode(response, 'GET', url, token);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final url = _url(path);
    _logRequest('POST', url);

    final response = await _send(
      () => _client.post(
        url,
        headers: _headers(token),
        body: jsonEncode(body),
      ),
      url,
    );

    return _decode(response, 'POST', url, token);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final url = _url(path);
    _logRequest('PUT', url);

    final response = await _send(
      () => _client.put(
        url,
        headers: _headers(token),
        body: jsonEncode(body),
      ),
      url,
    );

    return _decode(response, 'PUT', url, token);
  }

  Future<dynamic> delete(String path, {String? token}) async {
    final url = _url(path);
    _logRequest('DELETE', url);

    final response =
        await _send(() => _client.delete(url, headers: _headers(token)), url);

    return _decode(response, 'DELETE', url, token);
  }

  Future<dynamic> multipartPost(
    String path, {
    required String token,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String fileField = 'document',
    Map<String, String> fields = const {},
  }) async {
    final url = _url(path);
    _logRequest('POST multipart', url);

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll({'Authorization': 'Bearer $token'})
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          fileField,
          bytes,
          filename: fileName,
          contentType: _mediaType(mimeType),
        ),
      );

    final streamed = await _send(() => request.send(), url);
    final response = await http.Response.fromStream(streamed);

    return _decode(response, 'POST multipart', url, token);
  }

  Uri _url(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<T> _send<T extends http.BaseResponse>(
    Future<T> Function() request,
    Uri url,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      _logResponse('TIMEOUT', url, 408);
      throw ApiException(
        'The server took too long to respond. Please try again.',
        408,
      );
    } on http.ClientException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('========== API ERROR ==========');
        debugPrint('URL: $url');
        debugPrint('Exception: $e');
        debugPrint(stackTrace.toString());
        debugPrint('===============================');
      }

      _logResponse('NETWORK', url, 0);

      throw ApiException(
        'Cannot reach the server. Check your connection and try again.',
        0,
      );
    }
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  dynamic _decode(http.Response response, String method, Uri url, String? token) {
    _logResponse(method, url, response.statusCode);

    if (response.statusCode == 401 &&
        token != null &&
        token.isNotEmpty &&
        onSessionExpired != null) {
      // The session is no longer valid; surface it once so the caller can
      // clear the stored session and route back to sign in.
      onSessionExpired!();
    }

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

      throw ApiException(
        message ?? 'Request failed (${response.statusCode})',
        response.statusCode,
      );
    }

    return payload;
  }

  void _logRequest(String method, Uri url) {
    if (kDebugMode) {
      debugPrint('[MaidItQuick API] -> $method $url');
    }
  }

  void _logResponse(String method, Uri url, int statusCode) {
    if (kDebugMode) {
      debugPrint('[MaidItQuick API] <- $statusCode $method $url');
    }
  }
}

MediaType _mediaType(String mimeType) {
  final parts = mimeType.split('/');

  if (parts.length == 2) {
    return MediaType(parts[0], parts[1]);
  }

  return MediaType('application', 'octet-stream');
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}