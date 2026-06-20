import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'http_client.dart';

/// ApiService is a long-lived Provider singleton for API calls
/// Uses the role-based base_url set at login:
/// - Admin: http://10.102.0.68 (XAMPP direct)
/// - Operateur: http://192.168.4.1 (ESP32 direct)
/// 
/// No URL switching mid-session needed.
class ApiService extends ChangeNotifier {
  String? baseUrl;
  late IOClient _client;
  String? _sessionCookie;
  Map<String, dynamic>? _cachedStats;
  DateTime? _cachedStatsAt;

  ApiService({this.baseUrl, String? sessionCookie}) {
    _sessionCookie = sessionCookie;
    _initializeClient();
  }

  void _initializeClient() {
    if (baseUrl == null) {
      debugPrint('⚠️ ApiService: baseUrl is null, using default 192.168.4.1');
      baseUrl = 'http://192.168.4.1';
    }
    
    final uri = Uri.parse(baseUrl!);
    final host = uri.host;
    
    // Use plain HTTP client for http://, TLS client for https://
    if (uri.scheme == 'https') {
      debugPrint('🔒 ApiService: Using TLS client for HTTPS');
      _client = createTrustedClient(allowedHost: host);
    } else {
      debugPrint('🌐 ApiService: Using plain HTTP client');
      _client = IOClient(HttpClient());
    }
  }

  /// Update base URL and session cookie
  void updateBaseUrl({required String newBaseUrl, String? sessionCookie}) {
    final oldHost = Uri.parse(baseUrl ?? '192.168.4.1').host;
    final newHost = Uri.parse(newBaseUrl).host;
    
    baseUrl = newBaseUrl;
    if (sessionCookie != null) {
      _sessionCookie = sessionCookie;
    }

    // Recreate client if host changed
    if (oldHost != newHost) {
      try {
        _client.close();
      } catch (_) {}
      _initializeClient();
    }

    debugPrint('✅ ApiService: Updated baseUrl to $newBaseUrl');
    notifyListeners();
  }

  /// Load saved base_url from SharedPreferences (set at login by role)
  Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('simple_base_url');
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
      debugPrint('📥 ApiService: Loaded simple_base_url from prefs: $savedUrl');
      updateBaseUrl(newBaseUrl: savedUrl);
    } else {
      debugPrint('⚠️ ApiService: No simple_base_url found in prefs');
    }
  }

  /// Update session cookie (called after successful login)
  void setSessionCookie(String? cookie) {
    _sessionCookie = cookie;
    debugPrint('🍪 ApiService: Session cookie set: ${cookie != null ? 'YES' : 'NO'}');
  }

  bool get hasCachedStats => _cachedStats != null;
  Map<String, dynamic>? get cachedStats => _cachedStats;

  bool _isFreshCache() {
    final cachedAt = _cachedStatsAt;
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) < const Duration(seconds: 30);
  }

  @override
  void dispose() {
    try {
      _client.close();
    } catch (_) {}
    super.dispose();
  }

  /// Build headers with session cookie
  Map<String, String> _buildHeaders({String? contentType}) {
    final headers = {'Content-Type': contentType ?? 'application/json'};
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  Future<Map<String, dynamic>> getStats({bool useCache = true}) async {
    if (useCache && _cachedStats != null && _isFreshCache()) {
      return _cachedStats!;
    }

    if (baseUrl == null || baseUrl!.isEmpty) {
      debugPrint('❌ ApiService.getStats: baseUrl is not set');
      return {'error': 'No base URL configured'};
    }

    // Retry logic for connection errors
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final uri = Uri.parse('$baseUrl/Reader/get_stats.php');
        debugPrint('🔄 ApiService.getStats attempt $attempt: $uri');
        
        final response = 
            await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          _cachedStats = decoded;
          _cachedStatsAt = DateTime.now();
          return decoded;
        }
        
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        debugPrint('❌ ApiService.getStats attempt $attempt error: $e');
        
        // If connection error on first attempt, recreate client and retry
        if (attempt == 1 && e.toString().contains('Connection')) {
          debugPrint('🔧 Recreating HTTP client due to connection error');
          try {
            _client.close();
          } catch (_) {}
          _initializeClient();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue; // Retry
        }
        
        return {'error': e.toString()};
      }
    }
    
    return {'error': 'Failed after retries'};
  }

  void prefetchStats() {
    getStats(useCache: false).catchError((e) {
      debugPrint('❌ ApiService.prefetchStats error: $e');
      return <String, dynamic>{'error': e.toString()};
    });
  }

  /// Get all theft alerts detected at the door
  Future<Map<String, dynamic>> getAlerts({int limit = 50}) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      debugPrint('❌ ApiService.getAlerts: baseUrl is not set');
      return {'alerts': [], 'unread_count': 0, 'error': 'No base URL configured'};
    }

    // Retry logic for connection errors
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final uri = Uri.parse('$baseUrl/Reader/get_alerts.php?limit=$limit');
        debugPrint('🔄 ApiService.getAlerts attempt $attempt: $uri');
        
        final response = 
            await _client.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'alerts': List<Map<String, dynamic>>.from(data['alerts'] ?? []),
            'unread_count': (data['unread_count'] ?? 0) as int
          };
        }
        
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        debugPrint('❌ ApiService.getAlerts attempt $attempt error: $e');
        
        // If connection error on first attempt, recreate client and retry
        if (attempt == 1 && e.toString().contains('Connection')) {
          debugPrint('🔧 Recreating HTTP client due to connection error');
          try {
            _client.close();
          } catch (_) {}
          _initializeClient();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue; // Retry
        }
        
        return {'alerts': [], 'unread_count': 0, 'error': e.toString()};
      }
    }
    
    return {'alerts': [], 'unread_count': 0, 'error': 'Failed after retries'};
  }

  /// Mark an alert as read
  Future<bool> markAlertAsRead(int alertId) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      debugPrint('❌ ApiService.markAlertAsRead: baseUrl is not set');
      return false;
    }

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final uri = Uri.parse('$baseUrl/Reader/mark_alert_read.php');
        final response = await _client.post(
          uri,
          headers: _buildHeaders(contentType: 'application/x-www-form-urlencoded'),
          body: 'alert_id=$alertId'
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) return true;
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        debugPrint('❌ ApiService.markAlertAsRead attempt $attempt error: $e');
        
        if (attempt == 1 && e.toString().contains('Connection')) {
          try { _client.close(); } catch (_) {}
          _initializeClient();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        
        return false;
      }
    }
    return false;
  }

  /// Clear all theft alerts
  Future<bool> clearAllAlerts() async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      debugPrint('❌ ApiService.clearAllAlerts: baseUrl is not set');
      return false;
    }

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final uri = Uri.parse('$baseUrl/Reader/clear_alerts.php');
        final response = await _client.post(uri, headers: _buildHeaders())
            .timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) return true;
        throw Exception('HTTP ${response.statusCode}');
      } catch (e) {
        debugPrint('❌ ApiService.clearAllAlerts attempt $attempt error: $e');
        
        if (attempt == 1 && e.toString().contains('Connection')) {
          try { _client.close(); } catch (_) {}
          _initializeClient();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        
        return false;
      }
    }
    return false;
  }

  /// Helper: Get tags (returns raw JSON map or error)
  Future<Map<String, dynamic>> getTags() async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      debugPrint('❌ ApiService.getTags: baseUrl is not set');
      return {'error': 'No base URL configured'};
    }

    try {
      if (_sessionCookie == null || _sessionCookie!.isEmpty) {
        return {'error': 'Not authenticated: session cookie is missing'};
      }
      
      final uri = Uri.parse('$baseUrl/Reader/get_tags.php');
      final response = await _client.get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = response.body.trimLeft();
      if (body.startsWith('<!DOCTYPE html>') || body.startsWith('<html')) {
        return {'error': 'Not authenticated: server returned HTML', 'body': response.body};
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ ApiService.getTags error: $e');
      return {'error': e.toString()};
    }
  }

  /// Get tag details by EPC
  Future<Map<String, dynamic>> getTagDetails(String epc) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      debugPrint('❌ ApiService.getTagDetails: baseUrl is not set');
      return {'error': 'No base URL configured'};
    }

    try {
      final uri = Uri.parse('$baseUrl/Reader/check.php?epc=$epc');
      final response = await _client.get(uri, headers: _buildHeaders())
          .timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ ApiService.getTagDetails error: $e');
      return {'error': e.toString()};
    }
  }
}
