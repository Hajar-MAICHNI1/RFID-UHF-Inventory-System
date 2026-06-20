import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

/// EspService provides real-time push updates from ESP32 via WebSocket
/// This replaces HTTP polling with a single persistent connection
/// 
/// Message types from ESP32:
/// - check_result:   {"type":"check_result","epc":"ABC","result":"FOUND"}
/// - save_result:    {"type":"save_result","epc":"ABC","status":"ok"}
/// - saveall_result: {"type":"saveall_result","saved":45,"failed":2}
/// - tags_batch:     {"type":"tags_batch","epcs":["A","B","C"]}
class EspService extends ChangeNotifier {
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _connected = false;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _baseReconnectDelay = Duration(seconds: 2);

  // Latest message from ESP32
  Map<String, dynamic>? _lastMessage;

  bool get connected => _connected;
  Map<String, dynamic>? get lastMessage => _lastMessage;

  /// Listen to incoming WebSocket messages
  /// Returns a stream of parsed JSON objects
  Stream<Map<String, dynamic>>? getMessageStream() {
    if (_channel == null) return null;
    return _channel!.stream
        .map((message) {
          try {
            return jsonDecode(message) as Map<String, dynamic>;
          } catch (e) {
            debugPrint('❌ EspService: Failed to parse message: $message\nError: $e');
            return <String, dynamic>{'error': 'parse_error', 'raw': message};
          }
        })
        .handleError((error) {
          debugPrint('❌ EspService stream error: $error');
          _onStreamError(error);
        });
  }

  /// Connect to ESP32 WebSocket
  /// The WebSocket URL is typically: ws://192.168.4.1:81 or ws://192.168.4.1:8080
  Future<void> connect(String espIp, {String? cookie}) async {
    _manualDisconnect = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();

    await _disconnectInternal(notify: false);

    final wsUrl = _normalizeWebSocketUrl(espIp);
    debugPrint('🔌 EspService: Connecting to $wsUrl');

    try {
      final headers = <String, String>{};
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Connect to WebSocket with headers and keepalive
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        headers: headers,
        pingInterval: const Duration(seconds: 30),
      );

      // Start listening to messages
      _subscription = _channel!.stream.listen(
        (message) => _onMessage(message),
        onError: (error) => _onStreamError(error),
        onDone: () => _onStreamDone(),
        cancelOnError: false,
      );

      _setConnected(true);
      debugPrint('✅ EspService: Connected to ESP32 WebSocket');
    } catch (e) {
      debugPrint('❌ EspService: Connection failed: $e');
      _setConnected(false);
      _scheduleReconnect(espIp);
    }
  }

  /// Disconnect gracefully
  Future<void> disconnect() async {
    _manualDisconnect = true;
    await _disconnectInternal(notify: true);
  }

  Future<void> _disconnectInternal({bool notify = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (notify) {
      _setConnected(false);
    }
  }

  void _onMessage(dynamic message) {
    try {
      if (message is! String) {
        debugPrint('❌ EspService: Received non-string message: $message');
        return;
      }

      final data = jsonDecode(message) as Map<String, dynamic>;
      _lastMessage = data;

      debugPrint('📨 EspService received: ${data['type']} - $data');

      // Notify listeners of new message
      notifyListeners();
    } catch (e) {
      debugPrint('❌ EspService: Failed to parse message: $message\nError: $e');
    }
  }

  void _onStreamError(dynamic error) {
    debugPrint('❌ EspService: Stream error: $error');
    _setConnected(false);
  }

  void _onStreamDone() {
    debugPrint('⚠️ EspService: Stream done (connection closed)');
    _setConnected(false);

    if (!_manualDisconnect) {
      _scheduleReconnect(_getLastConnectedIp());
    }
  }

  void _scheduleReconnect(String? espIp) {
    if (_manualDisconnect || espIp == null) return;
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      debugPrint('❌ EspService: Max reconnection attempts reached');
      return;
    }

    _reconnectAttempt++;
    final delayMs = _baseReconnectDelay.inMilliseconds * _reconnectAttempt;
    final delay = Duration(milliseconds: delayMs.clamp(0, 60000)); // Cap at 60s

    debugPrint('⏳ EspService: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      connect(espIp);
    });
  }

  void _setConnected(bool connected) {
    if (_connected != connected) {
      _connected = connected;
      notifyListeners();
    }
  }

  String _normalizeWebSocketUrl(String espIp) {
    var ip = espIp.trim();

    // If it already has a scheme, return as-is (but ensure WS/WSS)
    if (ip.startsWith('ws://') || ip.startsWith('wss://')) {
      return ip;
    }

    // If it has http/https, convert to ws/wss and preserve the port
    if (ip.startsWith('https://')) {
      ip = ip.replaceFirst('https://', 'wss://');
      // If no port specified, add default HTTPS WebSocket port 443
      if (!ip.contains(':') && !ip.contains('/')) {
        ip = '$ip:443';
      }
      return ip;
    }
    if (ip.startsWith('http://')) {
      ip = ip.replaceFirst('http://', 'ws://');
      // If no port specified, use port 80 (same as HTTP server)
      if (!ip.contains(':') && !ip.contains('/')) {
        ip = '$ip:80';
      }
      return ip;
    }

    // Bare IP or hostname: add ws:// and port 80 for plain HTTP
    if (!ip.contains(':')) {
      ip = '$ip:80'; // Default to HTTP WebSocket on port 80
    }

    return 'ws://$ip';
  }

  String? _getLastConnectedIp() {
    if (_channel == null) return null;
    // Extract from the channel (this is a bit tricky, fallback to null)
    return null;
  }

  /// Send a message to ESP32 (e.g., to change mode or control settings)
  void sendMessage(String action, {Map<String, dynamic>? params}) {
    if (!_connected || _channel == null) {
      debugPrint('⚠️ EspService: Cannot send message - not connected');
      return;
    }

    try {
      final message = {
        'action': action,
        ...?params,
      };
      _channel!.sink.add(jsonEncode(message));
      debugPrint('📤 EspService sent: $message');
    } catch (e) {
      debugPrint('❌ EspService: Failed to send message: $e');
    }
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _disconnectInternal(notify: false);
    super.dispose();
  }
}
