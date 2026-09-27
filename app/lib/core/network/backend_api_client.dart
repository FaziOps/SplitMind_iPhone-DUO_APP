import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../error/ai_exceptions.dart';
import 'api_config.dart';
import 'auth_token_store.dart';

/// Base client for the SplitMind backend proxy (PRD: core/network).
///
/// Handles anonymous sign-in, attaches the bearer token, re-authenticates
/// once on 401, and maps HTTP and transport failures to [AiRequestException]s.
class BackendApiClient {
  BackendApiClient({
    required http.Client httpClient,
    required AuthTokenStore tokenStore,
    String baseUrl = ApiConfig.baseUrl,
    this._timeout = ApiConfig.requestTimeout,
  }) : _http = httpClient,
       _tokens = tokenStore,
       _baseUri = Uri.parse(baseUrl);

  final http.Client _http;
  final AuthTokenStore _tokens;
  final Uri _baseUri;
  final Duration _timeout;
  Future<String>? _pendingSignIn;

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    for (var attempt = 0; ; attempt++) {
      final token = await _ensureToken();
      final response = await _send(
        () => _http.post(
          _baseUri.resolve(path),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
          body: jsonEncode(body),
        ),
      );
      if (response.statusCode == 401 && attempt == 0) {
        await _tokens.clear();
        continue;
      }
      return _decode(response);
    }
  }

  Future<String> _ensureToken() async {
    final stored = await _tokens.read();
    if (stored != null && stored.isNotEmpty) return stored;
    // Coalesce concurrent sign-ins into one request.
    return _pendingSignIn ??= _signIn().whenComplete(() => _pendingSignIn = null);
  }

  Future<String> _signIn() async {
    final response = await _send(() => _http.post(_baseUri.resolve('/v1/auth/anonymous')));
    final json = _decode(response);
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const ServerException('Sign-in failed: the server returned no token.');
    }
    await _tokens.write(token);
    return token;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      json = decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      json = const {};
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;

    final code = json['error'] as String?;
    final message = json['message'] as String?;
    final retryAfterMs = json['retryAfterMs'];

    switch ((status, code)) {
      case (401, _):
        throw const UnauthorizedException();
      case (429, 'quota_exceeded'):
        final resetsAt = (json['quota'] as Map?)?['resetsAt'];
        throw QuotaExceededException(resetsAt: resetsAt is String ? DateTime.tryParse(resetsAt) : null);
      case (429, _):
        throw RateLimitedException(
          retryAfter: retryAfterMs is num ? Duration(milliseconds: retryAfterMs.toInt()) : null,
        );
      case (422, 'safety_blocked'):
        throw const SafetyBlockedException();
      case (504, _):
        throw const RequestTimeoutException();
      case (400 || 413, _):
        throw InvalidRequestException(message ?? 'The request was rejected.');
      default:
        throw ServerException(message ?? 'The AI service is unavailable right now.', status);
    }
  }
}
