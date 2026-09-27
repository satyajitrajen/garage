import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Thin HTTP wrapper over the Go backend.
///
/// - Sends `Authorization: Bearer <access>` and `X-Garage-Id` on every
///   garage-scoped call.
/// - Decodes the server's `{"error":{"code","message"}}` envelope into
///   [ApiException].
/// - On the first 401, invokes [onUnauthorized] (the [AuthProvider] refresh
///   hook) once and retries the request with the new token.
///
/// Timeouts come from [ApiConfig.timeout]. Bodies are capped server-side at
/// 1 MiB; this client never sends more than a single document + its items.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.onUnauthorized,
  })  : baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  String? accessToken;
  String? refreshToken;
  String? garageId;

  /// Called once on 401. Should refresh tokens and update [accessToken].
  /// Return `true` when a retry should be attempted.
  Future<bool> Function()? onUnauthorized;

  /// The refresh currently in flight. Every request that hits a 401 while it
  /// runs awaits this same future (however long it takes) instead of starting
  /// a second refresh with an already-rotated refresh token.
  Future<bool>? _refreshing;

  Future<bool> _refreshOnce() =>
      _refreshing ??= onUnauthorized!().whenComplete(() => _refreshing = null);

  Map<String, String> _headers({bool withGarage = true}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null && accessToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $accessToken';
    }
    if (withGarage && garageId != null && garageId!.isNotEmpty) {
      h['X-Garage-Id'] = garageId!;
    }
    return h;
  }

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } on FormatException {
      throw ApiException(res.statusCode, 'invalid_response',
          'Server returned an unreadable response.');
    }
  }

  Never _throwEnvelope(http.Response res) {
    String code = 'unknown';
    String message = 'Request failed (${res.statusCode}).';
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        final err = body['error'];
        if (err is Map<String, dynamic>) {
          code = (err['code'] as String?) ?? code;
          message = (err['message'] as String?) ?? message;
        } else if (body['message'] is String) {
          message = body['message'] as String;
        }
      }
    } catch (_) {
      // Keep defaults.
    }
    throw ApiException(res.statusCode, code, message);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) call, {
    bool withGarage = true,
    bool retryOnAuth = true,
  }) async {
    Future<http.Response> attempt() async {
      try {
        return await call(_headers(withGarage: withGarage))
            .timeout(ApiConfig.timeout);
      } on TimeoutException {
        throw const ApiException(0, 'timeout', 'Request timed out.');
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(0, 'network_error', 'Network error: $e');
      }
    }

    final sentToken = accessToken;
    var res = await attempt();
    if (res.statusCode == 401 && retryOnAuth && onUnauthorized != null) {
      // If another request already rotated the token after this one was
      // sent, just retry with it; otherwise join (or start) the refresh.
      final ok = accessToken != sentToken || await _refreshOnce();
      if (ok) {
        res = await attempt();
        if (res.statusCode >= 200 && res.statusCode < 300) return res;
      }
      _throwEnvelope(res);
    }
    return res;
  }

  Future<dynamic> _handle(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwEnvelope(res);
  }

  Future<dynamic> get(String path, {bool withGarage = true}) async {
    final res = await _send(
      (h) => _http.get(_uri(path), headers: h),
      withGarage: withGarage,
    );
    return _handle(res);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(
      (h) => _http.post(_uri(path),
          headers: h, body: body == null ? null : jsonEncode(body)),
    );
    return _handle(res);
  }

  Future<dynamic> postNoGarage(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(
      (h) => _http.post(_uri(path),
          headers: h, body: body == null ? null : jsonEncode(body)),
      withGarage: false,
    );
    return _handle(res);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(
      (h) => _http.put(_uri(path),
          headers: h, body: body == null ? null : jsonEncode(body)),
    );
    return _handle(res);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(
      (h) => _http.patch(_uri(path),
          headers: h, body: body == null ? null : jsonEncode(body)),
    );
    return _handle(res);
  }

  Future<void> delete(String path) async {
    final res = await _send((h) => _http.delete(_uri(path), headers: h));
    await _handle(res);
  }

  /// Raw POST that returns the HTTP status (for endpoints like logout→204).
  Future<int> postStatus(String path, [Map<String, dynamic>? body]) async {
    final res = await _send(
      (h) => _http.post(_uri(path),
          headers: h, body: body == null ? null : jsonEncode(body)),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return res.statusCode;
    _throwEnvelope(res);
  }

  void close() => _http.close();
}
