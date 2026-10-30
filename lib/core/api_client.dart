import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'secure_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.code = 0]);
  final String message;
  final int code;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, SecretStore? store})
    : _client = client ?? http.Client(),
      store = store ?? const SecureStore();
  final http.Client _client;
  final SecretStore store;
  String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://iotroot.astraval.com',
  );
  String? _accessToken;
  String? _refreshToken;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _refreshing;
  void Function()? onSessionExpired;
  String email = '';
  bool get authenticated => _accessToken != null;
  String get accountKey => Uri.encodeComponent('$baseUrl|$email');
  int _generation = 0;
  Future<void> _storageQueue = Future.value();

  Future<void> _persist(Future<void> Function() action) {
    final next = _storageQueue.then((_) => action());
    _storageQueue = next.catchError((Object _) {});
    return next;
  }

  Future<bool> restore() async {
    final raw = await store.read('iotroot.session');
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      baseUrl = data['baseUrl'] as String;
      email = data['email'] as String;
      _accessToken = data['accessToken'] as String;
      _refreshToken = data['refreshToken'] as String;
      _expiresAt = DateTime.parse(data['expiresAt'] as String);
      return true;
    } on FormatException {
      await clearSession();
      return false;
    } on TypeError {
      await clearSession();
      return false;
    }
  }

  Future<void> login(String url, String email, String password) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiException('Enter a valid HTTP or HTTPS API URL.');
    }
    final generation = ++_generation;
    baseUrl = url.trim().replaceFirst(RegExp(r'/+$'), '');
    this.email = email.trim();
    final data = await request(
      '/api/auth/login',
      method: 'POST',
      authenticated: false,
      body: {'email': this.email, 'password': password},
    );
    await _saveTokens(Map<String, dynamic>.from(data as Map), generation);
  }

  Future<void> _saveTokens(Map<String, dynamic> data, int generation) async {
    if (generation != _generation) {
      throw const ApiException("Session changed.", 401);
    }
    if (data['accessToken'] is! String || data['refreshToken'] is! String) {
      throw const ApiException(
        'The server returned an invalid login response.',
      );
    }
    final expiry = DateTime.now().add(
      Duration(seconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 3600),
    );
    await _persist(
      () => store.write(
        'iotroot.session',
        jsonEncode({
          'baseUrl': baseUrl,
          'email': email,
          'accessToken': data['accessToken'],
          'refreshToken': data['refreshToken'],
          'expiresAt': expiry.toIso8601String(),
        }),
      ),
    );
    if (generation != _generation) {
      throw const ApiException('Session changed.', 401);
    }
    _accessToken = data['accessToken'] as String;
    _refreshToken = data['refreshToken'] as String;
    _expiresAt = expiry;
  }

  Future<void> _refresh() async {
    if (_refreshing != null) return _refreshing!;
    final generation = _generation;
    _refreshing = () async {
      try {
        if (_refreshToken == null) {
          throw const ApiException('Please sign in again.', 401);
        }
        final data = await request(
          '/api/auth/refresh-token',
          method: 'POST',
          authenticated: false,
          body: {'refreshToken': _refreshToken},
        );
        if (generation != _generation) {
          throw const ApiException('Session changed.', 401);
        }
        await _saveTokens(Map<String, dynamic>.from(data as Map), generation);
      } on ApiException catch (error) {
        if ([400, 401, 403].contains(error.code) && generation == _generation) {
          await clearSession();
          onSessionExpired?.call();
        }
        rethrow;
      }
    }();
    try {
      await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool retry = true,
  }) async {
    if (authenticated) {
      if (_accessToken == null) {
        throw const ApiException('Please sign in again.', 401);
      }
      if (DateTime.now().add(const Duration(seconds: 30)).isAfter(_expiresAt)) {
        await _refresh();
      }
    }
    final generation = _generation;
    final tokenUsed = _accessToken;
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    http.Response response;
    try {
      final req = http.Request(method, uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (authenticated) 'Authorization': 'Bearer $_accessToken',
        });
      if (body != null) req.body = jsonEncode(body);
      response = await _client
          .send(req)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const ApiException(
        'The API timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the API. Check the server URL and your connection.',
      );
    }
    if (authenticated && generation != _generation) {
      throw const ApiException('Session changed.', 401);
    }
    if (response.statusCode == 401 && authenticated && retry) {
      if (_accessToken == tokenUsed) await _refresh();
      return request(
        path,
        method: method,
        body: body,
        query: query,
        retry: false,
      );
    }
    if (response.statusCode == 401 && authenticated) {
      await clearSession();
      onSessionExpired?.call();
      throw const ApiException('Session expired. Please sign in again.', 401);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'The API returned an invalid response (${response.statusCode}).',
        response.statusCode,
      );
    }
    if (decoded is! Map) {
      throw const ApiException('The API returned an unexpected response.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['status'] == false) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed.',
        response.statusCode,
      );
    }
    return decoded['data'];
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    await clearSession();
    if (refresh != null) {
      try {
        await request(
          '/api/auth/logout',
          method: 'POST',
          authenticated: false,
          body: {'refreshToken': refresh},
        );
      } on ApiException {
        /* Local sign-out still succeeds while offline. */
      }
    }
  }

  Future<void> clearSession() async {
    _generation++;
    _accessToken = null;
    _refreshToken = null;
    await _persist(() => store.delete('iotroot.session'));
  }

  void dispose() => _client.close();
}
