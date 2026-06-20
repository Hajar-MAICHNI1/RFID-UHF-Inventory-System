import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const Duration _connectTimeout = Duration(seconds: 6);
  static const Duration _responseTimeout = Duration(seconds: 8);
  static const Duration _retryDelay = Duration(milliseconds: 600);

  String? _sessionCookie;
  // Hardcoded IPs for simplified architecture
  static const String _xamppBaseUrl = 'http://10.102.0.68';    // XAMPP admin login
  static const String _esp32BaseUrl = 'http://192.168.4.1:80'; // ESP32 operateur login (plain HTTP)
  String _espBaseUrl = _esp32BaseUrl;       // Used for WebSocket/fallback
  String _serverBaseUrl = _xamppBaseUrl;    // Data server for admin
  String _role = '';
  String _username = '';
  String? _lastError;

  // Backward-compatible alias used by older code paths.
  String get baseUrl => activeBaseUrl;
  String get activeBaseUrl => isAdmin ? _serverBaseUrl : _espBaseUrl;
  String get activeFallbackBaseUrl => isAdmin ? _espBaseUrl : _serverBaseUrl;
  String get espBaseUrl => _espBaseUrl;
  String get dataBaseUrl => _serverBaseUrl;
  String get role => _role;
  String get username => _username;
  String? get lastError => _lastError;
  String? get sessionCookie => _sessionCookie;  // Getter for session cookie
  bool get isAdmin => _role == 'admin';
  bool get isOperateur => _role == 'operateur';

  Future<String> getSimpleBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('simple_base_url') ?? 'http://10.102.0.68';
  }

  Uri _buildUri(String path, {String? baseUrl}) {
    final base = Uri.parse(baseUrl ?? _espBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(path: normalizedPath);
  }

  bool _isKnownEsp32Host(String host) {
    // Treat common private LAN addresses as "known ESP/XAMPP hosts" so we
    // attempt HTTP fallback when HTTPS handshake fails.
    if (host == 'localhost' || host == '127.0.0.1') return true;
    if (host.startsWith('192.168.')) return true;
    if (host.startsWith('10.')) return true;
    final re172 = RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.');
    if (re172.hasMatch(host)) return true;
    return false;
  }

  String _toHttpBase(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    return Uri(scheme: 'http', host: uri.host, port: uri.hasPort ? uri.port : 80).toString();
  }

  void _setLastError(String message) {
    _lastError = message;
    debugPrint('Auth error: $message');
  }

  HttpClient _makeClient({String? baseUrl}) {
    final expectedHost = Uri.parse(baseUrl ?? _espBaseUrl).host;

    // Allows interop with legacy ESP32 TLS stacks during handshake.
    final securityContext = SecurityContext(withTrustedRoots: false);
    securityContext.allowLegacyUnsafeRenegotiation = true;

    final client = HttpClient(context: securityContext);
    client.connectionTimeout = _connectTimeout;

    client.badCertificateCallback = (X509Certificate cert, String host, int port) =>
        host == expectedHost ||
        host == '10.102.0.68' ||
        host == 'localhost';

    return client;
  }

  String? _extractSessionCookie(HttpHeaders headers) {
    final cookieHeaders = headers[HttpHeaders.setCookieHeader];
    debugPrint('_extractSessionCookie: Set-Cookie headers count = ${cookieHeaders?.length ?? 0}');
    
    if (cookieHeaders == null || cookieHeaders.isEmpty) {
      debugPrint('_extractSessionCookie: No Set-Cookie headers found');
      return null;
    }

    for (final header in cookieHeaders) {
      debugPrint('_extractSessionCookie: Processing header: $header');
      
      // Try PHPSESSID first (standard PHP session)
      var match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(header);
      if (match != null) {
        debugPrint('_extractSessionCookie: Found PHPSESSID');
        return 'PHPSESSID=${match.group(1)}';
      }
      
      // Try custom "session" cookie
      match = RegExp(r'session=([^;]+)').firstMatch(header);
      if (match != null) {
        debugPrint('_extractSessionCookie: Found session cookie: session=${match.group(1)}');
        return 'session=${match.group(1)}';
      }
    }
    debugPrint('_extractSessionCookie: No matching cookie found in any header');
    return null;
  }

  Future<void> _persistSession(String sessionCookie, String role, {String? baseUrl, String? username}) async {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _espBaseUrl = baseUrl;
    }
    _sessionCookie = sessionCookie;
    _role = role;
    _username = username ?? '';
    final activeBaseUrl = this.baseUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', _sessionCookie!);
    await prefs.setString('esp_base_url', _espBaseUrl);
    await prefs.setString('server_base_url', _serverBaseUrl);
    // Keep legacy key for backward compatibility, but store the active role URL.
    await prefs.setString('base_url', activeBaseUrl);
    await prefs.setString('role', _role);
    
    // ✅ Store the actual baseUrl used for login (not hardcoded)
    // Admin: Use the XAMPP URL that login succeeded with
    // Operateur: Use the ESP32 URL that login succeeded with
    final simplifiedBaseUrl = baseUrl ?? activeBaseUrl;
    await prefs.setString('simple_base_url', simplifiedBaseUrl);
    debugPrint('✅ Saved simple_base_url for role=$_role: $simplifiedBaseUrl');
    
    if (_username.isNotEmpty) {
      await prefs.setString('username', _username);
    }
    notifyListeners();
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  // FIX 2: ESP32 now returns HTTP 200 + JSON instead of a 302 redirect.
  //        This sidesteps Flutter's broken redirect-with-cookie handling.
  //
  //  Success → { "status": "ok",    "role": "admin" | "operateur" }
  //  Failure → { "status": "error", "msg":  "..." }
  //
  //  The session cookie is still delivered via Set-Cookie in the *same* 200
  //  response, so we can read it directly without followRedirects tricks.
  Future<bool> login(String username, String password) async {
    final trimmedUser = username.trim();
    final trimmedPassword = password.trim();
    if (trimmedUser.isEmpty || trimmedPassword.isEmpty) {
      _setLastError('Username and password are required.');
      return false;
    }

    _lastError = null;

    Future<bool> doLoginAttempt(String baseUrl) async {
      final client = _makeClient(baseUrl: baseUrl);
      try {
        final host = Uri.parse(baseUrl).host;
        final primaryLoginPath = host.startsWith('10.') ? '/Reader/login.php' : '/login';
        final uri = _buildUri(primaryLoginPath, baseUrl: baseUrl);
        Future<HttpClientRequest> makePost(Uri u) => client.postUrl(u).timeout(_connectTimeout);

        final request = await makePost(uri);

        request.followRedirects = false;
        request.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded');
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');

        final body =
            'username=${Uri.encodeComponent(trimmedUser)}'
            '&password=${Uri.encodeComponent(trimmedPassword)}';
        request.contentLength = body.length;
        request.write(body);

        var response = await request.close().timeout(_responseTimeout);
        var bodyStr = await response
            .transform(utf8.decoder)
            .join()
            .timeout(_responseTimeout);

        // If the primary login path fails with 404 or HTML, try the alternate
        // path (`/login` <-> `/Reader/login.php`) before failing.
        if ((response.statusCode == 404 || bodyStr.trimLeft().startsWith('<!DOCTYPE HTML') || bodyStr.trimLeft().startsWith('<html')) && _isKnownEsp32Host(Uri.parse(baseUrl).host)) {
          try {
            final alternateLoginPath = primaryLoginPath == '/login' ? '/Reader/login.php' : '/login';
            final alt = _buildUri(alternateLoginPath, baseUrl: baseUrl);
            final altReq = await makePost(alt);
            altReq.followRedirects = false;
            altReq.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
            altReq.headers.set(HttpHeaders.acceptHeader, 'application/json');
            altReq.contentLength = body.length;
            altReq.write(body);
            response = await altReq.close().timeout(_responseTimeout);
            bodyStr = await response.transform(utf8.decoder).join().timeout(_responseTimeout);
            debugPrint('Tried alternate login path $alt → ${response.statusCode}');
          } catch (_) {
            // If alternate attempt fails, continue with original error handling below.
          }
        }

        debugPrint('Login HTTP ${response.statusCode} → $bodyStr');

        final sessionCookie = _extractSessionCookie(response.headers);
        debugPrint('🍪 Extracted session cookie: $sessionCookie');
        debugPrint('🔍 Current _sessionCookie value: $_sessionCookie');
        final inferredRole = trimmedUser == 'admin' ? 'admin' : 'operateur';

        if (response.statusCode == 200) {
          final dynamic decoded = jsonDecode(bodyStr);
          if (decoded is! Map<String, dynamic>) {
            _setLastError('Invalid login response format.');
            return false;
          }

          final Map<String, dynamic> json = decoded;
          if (json['status'] == 'ok') {
            if (sessionCookie != null) {
              debugPrint('✅ Persisting session with cookie: $sessionCookie');
              await _persistSession(
                sessionCookie,
                (json['role'] as String?) ?? inferredRole,
                baseUrl: baseUrl,
                username: trimmedUser,
              );
              // Warm TLS connection in background to reduce delay on first API call
              unawaited(_warmTlsConnection());
              debugPrint('✅ After _persistSession, _sessionCookie = $_sessionCookie');
              return true;
            }

            _setLastError('Login succeeded but no session cookie was received.');
            debugPrint('❌ Login succeeded but no session cookie extracted from headers');
            return false;
          }

          _setLastError((json['msg'] as String?) ?? 'Invalid username or password.');
          return false;
        }

        if (response.statusCode == 302 && sessionCookie != null) {
          debugPrint('✅ 302 redirect with cookie');
          await _persistSession(sessionCookie, inferredRole, baseUrl: baseUrl, username: trimmedUser);
          return true;
        }

        if (response.statusCode == 401) {
          _setLastError('Invalid username or password.');
          return false;
        }

        _setLastError('Unexpected status code: ${response.statusCode}.');
        return false;
      } finally {
        client.close(force: true);
      }
    }

    try {
      // ✅ Smart login: Try appropriate server first based on username
      // Admin → XAMPP first, then ESP32
      // Operateur → ESP32 first, then XAMPP
      final isAdminUser = trimmedUser == 'admin';
      
      if (isAdminUser) {
        // Admin: try XAMPP first (faster for admin)
        debugPrint('🔑 Admin detected - Attempting XAMPP: $_xamppBaseUrl');
        if (await doLoginAttempt(_xamppBaseUrl)) {
          return true;
        }
        
        debugPrint('🔑 XAMPP login failed, attempting ESP32: $_esp32BaseUrl');
        if (await doLoginAttempt(_esp32BaseUrl)) {
          return true;
        }
      } else {
        // Operateur: try ESP32 first (faster for operateur)
        debugPrint('🔑 Operateur detected - Attempting ESP32: $_esp32BaseUrl');
        if (await doLoginAttempt(_esp32BaseUrl)) {
          return true;
        }
        
        debugPrint('🔑 ESP32 login failed, attempting XAMPP: $_xamppBaseUrl');
        if (await doLoginAttempt(_xamppBaseUrl)) {
          return true;
        }
      }
      
      return false;
    } on HandshakeException {
      final uri = Uri.parse(_espBaseUrl);
      if (uri.scheme == 'https' && _isKnownEsp32Host(uri.host)) {
        await Future<void>.delayed(_retryDelay);
        final fallbackBase = _toHttpBase(_espBaseUrl);
        debugPrint('Retrying login over HTTP fallback: $fallbackBase');
        try {
          if (await doLoginAttempt(fallbackBase)) {
            return true;
          }
        } on HandshakeException {
          // HTTP fallback should not handshake; keep unified message if it still fails unexpectedly.
        }
      }
      _setLastError('TLS handshake failed. ESP32 HTTPS settings are incompatible.');
      return false;
    } on TimeoutException {
      await Future<void>.delayed(_retryDelay);
      try {
        if (await doLoginAttempt(_espBaseUrl)) {
          return true;
        }
      } on Object {
        // Keep the original timeout message below.
      }
      _setLastError('Connection timeout. Check ESP32 availability and try again.');
      return false;
    } on SocketException catch (e) {
      _setLastError('Network error: ${e.message}');
      return false;
    } on HttpException catch (e) {
      _setLastError('HTTP error: ${e.message}');
      return false;
    } on FormatException {
      _setLastError('Server returned malformed JSON.');
      return false;
    } catch (e) {
      _setLastError('Login failed: $e');
      return false;
    }
  }

  // Make a lightweight authenticated request to the ESP32 to pre-establish
  // the TLS session and reduce latency on the subsequent API call.
  Future<void> _warmTlsConnection() async {
    try {
      final uri = Uri.parse('$_espBaseUrl/Reader/get_tags.php');
      final host = Uri.parse(_espBaseUrl).host;
      final client = createTrustedClient(allowedHost: host);
      try {
        final headers = <String, String>{};
        if (_sessionCookie != null) headers[HttpHeaders.cookieHeader] = _sessionCookie!;
        // short timeout; we only need the handshake to complete
        final resp = await client.get(uri, headers: headers).timeout(const Duration(seconds: 3));
        debugPrint('Warm TLS response: ${resp.statusCode}');
      } catch (e) {
        debugPrint('Warm TLS failed: $e');
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Warm TLS setup error: $e');
    }
  }

  Future<bool> restoreSession() async {
    final prefs    = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
    
    // Load URLs and fix any cached HTTP URLs to HTTPS
    String espUrl = prefs.getString('esp_base_url') ?? prefs.getString('base_url') ?? 'https://192.168.4.1:443';
    String serverUrl = prefs.getString('server_base_url') ?? 'https://192.168.4.1:443';
    
    // Convert any HTTP URLs to HTTPS (migration from old cache)
    espUrl = _convertHttpToHttps(espUrl);
    serverUrl = _convertHttpToHttps(serverUrl);
    
    _espBaseUrl = espUrl;
    _serverBaseUrl = serverUrl;
    _role          = prefs.getString('role') ?? '';
    _username      = prefs.getString('username') ?? '';
    _lastError     = null;
    
    // Save the converted URLs back to preferences
    if (espUrl != (prefs.getString('esp_base_url') ?? '')) {
      await prefs.setString('esp_base_url', espUrl);
    }
    if (serverUrl != (prefs.getString('server_base_url') ?? '')) {
      await prefs.setString('server_base_url', serverUrl);
    }
    final activeBaseUrl = baseUrl;
    if (activeBaseUrl != (prefs.getString('base_url') ?? '')) {
      await prefs.setString('base_url', activeBaseUrl);
    }
    
    return _sessionCookie != null && _sessionCookie!.isNotEmpty;
  }

  // Helper: Convert old HTTP URLs to HTTPS for cached sessions
  String _convertHttpToHttps(String url) {
    if (url.startsWith('http://')) {
      // Convert http://IP:port to https://IP:443
      final uri = Uri.parse(url);
      return Uri(scheme: 'https', host: uri.host, port: 443).toString();
    }
    return url;
  }

  Future<void> logout() async {
    Future<void> doLogoutAttempt(String baseUrl) async {
      final client = _makeClient(baseUrl: baseUrl);
      try {
        final request = await client
            .getUrl(_buildUri('/logout', baseUrl: baseUrl))
            .timeout(_connectTimeout);
        request.followRedirects = false;
        request.headers.set('Cookie', _sessionCookie ?? '');
        final response = await request.close().timeout(_responseTimeout);
        await response.drain<void>();
      } finally {
        client.close(force: true);
      }
    }

    try {
      await doLogoutAttempt(_espBaseUrl);
    } on HandshakeException {
      final uri = Uri.parse(_espBaseUrl);
      if (uri.scheme == 'https' && _isKnownEsp32Host(uri.host)) {
        try {
          await doLogoutAttempt(_toHttpBase(_espBaseUrl));
        } on Object {
          debugPrint('Logout warning: fallback HTTP logout failed after TLS handshake error.');
        }
      } else {
        debugPrint('Logout warning: TLS handshake failed.');
      }
    } on TimeoutException {
      debugPrint('Logout warning: timeout while contacting device.');
    } catch (e) {
      debugPrint('Logout warning: $e');
    }

    _sessionCookie = null;
    _username      = '';
    _role          = '';
    _lastError     = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('base_url');
    await prefs.remove('esp_base_url');
    await prefs.remove('server_base_url');
    await prefs.remove('role');
    notifyListeners();
  }

  // ── Clear Session (Non-blocking) ────────────────────────────────────────
  // Clears local session state WITHOUT making network calls.
  // Use this during app startup to avoid ANR from network I/O on main thread.
  void clearSession() {
    _sessionCookie = null;
    _username      = '';
    _role          = '';
    _lastError     = null;
    notifyListeners();
  }

  Map<String, String> get authHeaders => {
        'Cookie': _sessionCookie ?? '',
      };
}