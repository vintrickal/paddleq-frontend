import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:paddleq/core/api/api_exception.dart';

/// Thin HTTP wrapper for the PaddleQ backend.
///
/// Centralizes JSON encode/decode, error parsing, and the dev/prod base URL
/// switch. Cubits should depend on the higher-level `PaddleqApi` facade
/// rather than instantiating this directly.
///
/// Override the base URL with `--dart-define=PADDLEQ_API_BASE=...` at build
/// time. The default targets a local ASP.NET Core dev server over HTTP.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : _base = Uri.parse(baseUrl ?? defaultBaseUrl),
        _http = httpClient ?? http.Client();

  static const defaultBaseUrl = String.fromEnvironment(
    'PADDLEQ_API_BASE',
    defaultValue: 'https://localhost:7276',
  );

  final Uri _base;
  final http.Client _http;

  /// Visible for diagnostics — e.g. an "API: ..." string in a debug overlay.
  String get baseUrl => _base.toString();

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send('POST', path, body: body, query: query);

  Future<dynamic> putJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send('PUT', path, body: body, query: query);

  void close() => _http.close();

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final uri = _resolve(path, query);
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      response = await switch (method) {
        'GET' => _http.get(uri, headers: headers),
        'POST' => _http.post(uri, headers: headers, body: encoded),
        'PUT' => _http.put(uri, headers: headers, body: encoded),
        _ => throw UnsupportedError('Unsupported method: $method'),
      };
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error — could not reach PaddleQ',
        cause: e,
      );
    }

    return _decode(response);
  }

  Uri _resolve(String path, Map<String, dynamic>? query) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final base = _base.toString().replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base$cleanPath');
    if (query == null || query.isEmpty) return uri;
    final stringified = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...stringified,
    });
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final bodyText = response.body;
    final isJson = (response.headers['content-type'] ?? '')
        .toLowerCase()
        .contains('json');

    if (status >= 200 && status < 300) {
      if (bodyText.isEmpty) return null;
      if (!isJson) return bodyText;
      try {
        return jsonDecode(bodyText);
      } catch (_) {
        return bodyText;
      }
    }

    // Error path — try to extract { message } or ValidationProblemDetails.
    String message = 'Request failed ($status)';
    Map<String, List<String>>? validationErrors;

    if (isJson && bodyText.isNotEmpty) {
      try {
        final decoded = jsonDecode(bodyText);
        if (decoded is Map<String, dynamic>) {
          if (decoded['message'] is String) {
            message = decoded['message'] as String;
          } else if (decoded['title'] is String) {
            message = decoded['title'] as String;
          }
          final errors = decoded['errors'];
          if (errors is Map<String, dynamic>) {
            validationErrors = {
              for (final entry in errors.entries)
                entry.key: (entry.value as List)
                    .map((v) => v.toString())
                    .toList(growable: false),
            };
          }
        }
      } catch (_) {/* fall through to generic message */}
    }

    throw ApiException(
      statusCode: status,
      message: message,
      validationErrors: validationErrors,
    );
  }
}
