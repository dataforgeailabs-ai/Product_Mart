import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// The single secure token store shared by login, requests, and logout.
const FlutterSecureStorage secureStorage = FlutterSecureStorage();

class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({
    http.Client? innerClient,
    FlutterSecureStorage? storage,
    Future<void> Function()? onSessionExpired,
  })  : _inner = innerClient ?? http.Client(),
        _storage = storage ?? secureStorage,
        _onSessionExpired = onSessionExpired;

  static final AuthenticatedHttpClient instance = AuthenticatedHttpClient();
  static Future<void> Function()? sessionExpiredHandler;

  final http.Client _inner;
  final FlutterSecureStorage _storage;
  final Future<void> Function()? _onSessionExpired;

  Future<_RefreshOutcome>? _refreshInFlight;
  Future<void>? _expiryInFlight;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isTokenEndpoint(request.url)) {
      return _inner.send(request);
    }

    final accessToken = await _storage.read(key: 'access_token');
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }

    // Buffer the body so even streamed multipart uploads can be replayed once.
    final bodyBytes = await request.finalize().toBytes();
    final firstResponse = await _sendCopy(
      request: request,
      bodyBytes: bodyBytes,
      accessToken: accessToken,
    );
    if (firstResponse.statusCode != 401) return firstResponse;

    // A parallel request may already have refreshed the token while this
    // response was in flight. Reuse it instead of refreshing again.
    final currentToken = await _storage.read(key: 'access_token');
    if (currentToken == null || currentToken.isEmpty) return firstResponse;

    final refreshOutcome = currentToken != accessToken
        ? _RefreshOutcome(token: currentToken)
        : await _refreshOrJoin();
    if (refreshOutcome.token == null) {
      if (refreshOutcome.rejected) return firstResponse;
      throw http.ClientException(
        'Unable to refresh the authentication session. Please try again.',
        request.url,
      );
    }

    final retryResponse = await _sendCopy(
      request: request,
      bodyBytes: bodyBytes,
      accessToken: refreshOutcome.token!,
    );
    if (retryResponse.statusCode == 401) {
      await _expireSession();
    }
    return retryResponse;
  }

  bool _isTokenEndpoint(Uri uri) {
    final loginPath = Uri.parse(ApiConfig.login).path;
    final refreshPath = Uri.parse(ApiConfig.refreshToken).path;
    return uri.path == loginPath || uri.path == refreshPath;
  }

  Future<http.StreamedResponse> _sendCopy({
    required http.BaseRequest request,
    required List<int> bodyBytes,
    required String accessToken,
  }) {
    final retry = http.Request(request.method, request.url)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..headers.addAll(request.headers)
      ..bodyBytes = bodyBytes;
    retry.headers['Authorization'] = 'Bearer $accessToken';
    return _inner.send(retry);
  }

  Future<_RefreshOutcome> _refreshOrJoin() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<_RefreshOutcome> sharedOperation;
    sharedOperation = _performRefresh().then((outcome) async {
      if (outcome.token == null && outcome.rejected) {
        await _expireSession();
      }
      return outcome;
    }).whenComplete(() {
      if (identical(_refreshInFlight, sharedOperation)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = sharedOperation;

    return sharedOperation;
  }

  Future<_RefreshOutcome> _performRefresh() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        return const _RefreshOutcome(rejected: true);
      }

      final response = await _inner.post(
        Uri.parse(ApiConfig.refreshToken),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      if (response.statusCode == 400 || response.statusCode == 401) {
        return const _RefreshOutcome(rejected: true);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _RefreshOutcome();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const _RefreshOutcome();
      final access = decoded['access']?.toString();
      if (access == null || access.isEmpty) return const _RefreshOutcome();

      await _storage.write(key: 'access_token', value: access);
      final rotatedRefresh = decoded['refresh']?.toString();
      if (rotatedRefresh != null && rotatedRefresh.isNotEmpty) {
        await _storage.write(key: 'refresh_token', value: rotatedRefresh);
      }
      return _RefreshOutcome(token: access);
    } catch (_) {
      // Network or storage errors should fail the request without discarding
      // credentials that may still be valid.
      return const _RefreshOutcome();
    }
  }

  Future<void> _expireSession() {
    final inFlight = _expiryInFlight;
    if (inFlight != null) return inFlight;
    late final Future<void> expiration;
    expiration = () async {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      final handler = _onSessionExpired ?? sessionExpiredHandler;
      if (handler != null) await handler();
    }().whenComplete(() {
      if (identical(_expiryInFlight, expiration)) _expiryInFlight = null;
    });
    _expiryInFlight = expiration;
    return expiration;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class _RefreshOutcome {
  const _RefreshOutcome({this.token, this.rejected = false});

  final String? token;
  final bool rejected;
}
