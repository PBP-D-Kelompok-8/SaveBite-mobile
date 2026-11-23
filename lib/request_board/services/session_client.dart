import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Base URL default untuk backend Django SaveBite di PWS.
/// Dapat di-override saat build/run dengan:
/// `--dart-define=SAVEBITE_BASE_URL=http://127.0.0.1:8000`
const String defaultSaveBiteBaseUrl = String.fromEnvironment(
  'SAVEBITE_BASE_URL',
  defaultValue: 'https://reshandy-taftazani-savebite.pws.cs.ui.ac.id',
);

/// Menghasilkan UUID v4 acak (RFC 4122) menggunakan [Random.secure]
/// untuk header `Idempotency-Key` pada pembuatan request.
String generateUuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set version 4 (0100xxxx)
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Set variant RFC 4122 (10xxxxxx)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-'
      '${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}

/// Exception saat login atau pengelolaan sesi gagal.
class SaveBiteAuthException implements Exception {
  final String message;

  const SaveBiteAuthException(this.message);

  @override
  String toString() => message;
}

/// Client HTTP berbasis sesi Django (`SessionAuthentication` + `X-CSRFToken`)
/// yang mengelola cookie sesi, token CSRF, dan identitas pengguna aktif.
class SaveBiteSessionClient extends ChangeNotifier {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  final Map<String, String> _cookies = {};
  int? _currentUserId;
  String? _currentUsername;

  SaveBiteSessionClient({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? defaultSaveBiteBaseUrl),
        _httpClient = httpClient ?? http.Client();

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// ID pengguna yang sedang login (`null` bila tamu / belum login).
  int? get currentUserId => _currentUserId;

  /// Username pengguna yang sedang login (`null` bila tamu / belum login).
  String? get currentUsername => _currentUsername;

  /// Nilai cookie `csrftoken` terbaru jika sudah diperoleh dari server.
  String? get csrfToken => _cookies['csrftoken'];

  /// Nilai cookie `sessionid` terbaru jika pengguna sudah login.
  String? get sessionId => _cookies['sessionid'];

  /// Bernilai `true` apabila client memiliki `sessionid` aktif.
  bool get isAuthenticated =>
      _cookies['sessionid'] != null && _cookies['sessionid']!.isNotEmpty;

  /// Salinan read-only cookie yang tersimpan saat ini.
  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  /// Mengatur sesi secara manual (berguna untuk pemulihan sesi atau pengujian).
  void setSession({
    String? sessionId,
    String? csrfToken,
    int? userId,
    String? username,
  }) {
    if (sessionId != null && sessionId.isNotEmpty) {
      _cookies['sessionid'] = sessionId;
    } else {
      _cookies.remove('sessionid');
    }

    if (csrfToken != null && csrfToken.isNotEmpty) {
      _cookies['csrftoken'] = csrfToken;
    }

    _currentUserId = userId;
    _currentUsername = username;
    notifyListeners();
  }

  /// Login ke view `/login/` Django menggunakan form HTML (`csrfmiddlewaretoken`,
  /// `username`, `password`) dan menyimpan `sessionid` serta `csrftoken` dari
  /// header `Set-Cookie`.
  ///
  /// Mengembalikan `true` apabila server merespons redirect sukses (`302` ke
  /// selain `/login/`) atau `200` dengan cookie `sessionid` baru.
  Future<void> login({
    required String username,
    required String password,
    int? userId,
  }) async {
    final loginUri = Uri.parse('$baseUrl/login/');

    final getResponse = await _httpClient.get(
      loginUri,
      headers: _buildHeaders(),
    ).timeout(timeout);
    _updateCookiesFromHeaders(getResponse.headers);

    final hiddenCsrf = _extractHiddenCsrfToken(getResponse.body);
    final csrfValue = hiddenCsrf ?? _cookies['csrftoken'] ?? '';

    final postRequest = http.Request('POST', loginUri)
      ..followRedirects = false
      ..headers.addAll(
        _buildHeaders(
          includeCsrf: true,
          contentType: 'application/x-www-form-urlencoded',
          extraHeaders: {
            'Referer': loginUri.toString(),
            'Origin': baseUrl,
          },
        ),
      )
      ..bodyFields = {
        if (csrfValue.isNotEmpty) 'csrfmiddlewaretoken': csrfValue,
        'username': username,
        'password': password,
      };

    final streamed = await _httpClient.send(postRequest).timeout(timeout);
    final postResponse = await http.Response.fromStream(streamed);
    _updateCookiesFromHeaders(postResponse.headers);

    final location = postResponse.headers['location'] ?? '';
    final isRedirectSuccess = (postResponse.statusCode == 302 ||
            postResponse.statusCode == 303) &&
        !location.contains('/login');

    if (isRedirectSuccess ||
        (postResponse.statusCode == 200 && isAuthenticated)) {
      _currentUsername = username;
      if (userId != null) {
        _currentUserId = userId;
      }
      notifyListeners();
      return;
    }

    if (postResponse.statusCode == 403) {
      throw const SaveBiteAuthException(
        'Verifikasi CSRF gagal saat login. Silakan coba lagi.',
      );
    }

    throw const SaveBiteAuthException(
      'Username atau password salah, atau sesi login ditolak server.',
    );
  }

  /// Logout dari server (`/logout/`) dan menghapus seluruh state sesi lokal.
  Future<void> logout() async {
    try {
      if (isAuthenticated) {
        final logoutUri = Uri.parse('$baseUrl/logout/');
        final response = await send(
          method: 'POST',
          uri: logoutUri,
          extraHeaders: {
            'Referer': '$baseUrl/',
            'Origin': baseUrl,
          },
        );
        _updateCookiesFromHeaders(response.headers);
      }
    } catch (_) {
      // Tetap bersihkan state lokal meskipun jaringan gagal saat logout.
    } finally {
      clearSession();
    }
  }

  /// Menghapus cookie sesi dan identitas pengguna di memori lokal.
  void clearSession() {
    _cookies.clear();
    _currentUserId = null;
    _currentUsername = null;
    notifyListeners();
  }

  /// Mengirim HTTP request dengan cookie sesi dan header `X-CSRFToken` otomatis
  /// untuk method mutasi (`POST`, `PATCH`, `PUT`, `DELETE`).
  Future<http.Response> send({
    required String method,
    required Uri uri,
    String? body,
    String? contentType,
    Map<String, String>? extraHeaders,
  }) async {
    final upperMethod = method.toUpperCase();
    final isMutating = upperMethod == 'POST' ||
        upperMethod == 'PATCH' ||
        upperMethod == 'PUT' ||
        upperMethod == 'DELETE';

    final request = http.Request(upperMethod, uri);
    request.headers.addAll(
      _buildHeaders(
        includeCsrf: isMutating,
        contentType: contentType,
        extraHeaders: {
          if (isMutating) 'Referer': '$baseUrl/',
          ...?extraHeaders,
        },
      ),
    );

    if (body != null) {
      request.body = body;
    }

    final streamed = await _httpClient.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    _updateCookiesFromHeaders(response.headers);
    return response;
  }

  Map<String, String> _buildHeaders({
    bool includeCsrf = false,
    String? contentType,
    Map<String, String>? extraHeaders,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }

    if (_cookies.isNotEmpty) {
      headers['Cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }

    if (includeCsrf && csrfToken != null && csrfToken!.isNotEmpty) {
      headers['X-CSRFToken'] = csrfToken!;
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  String? _extractHiddenCsrfToken(String html) {
    final match = RegExp(
      r'''name=["']csrfmiddlewaretoken["']\s+value=["']([^"']+)["']''',
    ).firstMatch(html);
    if (match != null) {
      return match.group(1);
    }
    final reverseMatch = RegExp(
      r'''value=["']([^"']+)["']\s+name=["']csrfmiddlewaretoken["']''',
    ).firstMatch(html);
    return reverseMatch?.group(1);
  }

  void _updateCookiesFromHeaders(Map<String, String> headers) {
    String? setCookieHeader;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'set-cookie') {
        setCookieHeader = entry.value;
        break;
      }
    }
    if (setCookieHeader == null || setCookieHeader.isEmpty) {
      return;
    }

    // Pisahkan beberapa cookie tanpa memotong koma di dalam atribut Expires.
    final cookieParts = setCookieHeader.split(
      RegExp(r',(?=\s*[A-Za-z0-9_!#$%&*+\-.^`|~]+=)'),
    );

    for (final part in cookieParts) {
      final firstSegment = part.split(';').first.trim();
      final eqIndex = firstSegment.indexOf('=');
      if (eqIndex <= 0) continue;

      final name = firstSegment.substring(0, eqIndex).trim();
      final value = firstSegment.substring(eqIndex + 1).trim();
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}
