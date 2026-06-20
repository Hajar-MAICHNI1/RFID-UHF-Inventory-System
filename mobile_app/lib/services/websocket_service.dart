import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'http_client.dart';

/// Connects to the ESP32 WebSocket endpoint and mirrors the latest JSON state
/// into `state` so the UI can react to push updates instead of polling.
class WebSocketService extends ChangeNotifier {
  final Map<String, dynamic> _state = {
    'wifi': false,
    'mode': 'CHECK',
    'relay': false,
    'tag': '',
    'tagDetecte': false,
    'checkList': <Map<String, dynamic>>[],
    'batchList': <Map<String, dynamic>>[],
    'batchPending': false,
    'batchResult': '',
    'timeLeft': 0,
    'message': '',
    'msgType': '',
  };
  bool _connected = false;
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;
  String? _currentUrl;
  String? _currentCookie;
  int _reconnectAttempt = 0;

  Map<String, dynamic> get state => _state;
  bool get connected => _connected;

  Future<void> connect(String ip, {String? cookie, String? fallback}) async {
    _manualDisconnect = false;
    _currentCookie = cookie;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await _disconnectInternal(notify: false);
    _setDisconnected();

    final candidates = <String>[_normalizeWebSocketUrl(ip)];
    if (fallback != null && fallback.trim().isNotEmpty) {
      final normalizedFallback = _normalizeWebSocketUrl(fallback);
      if (!candidates.contains(normalizedFallback)) {
        candidates.add(normalizedFallback);
      }
    }

    for (final candidate in candidates) {
      if (await _openConnection(candidate)) {
        _currentUrl = candidate;
        return;
      }
    }

    _scheduleReconnect();
  }

  String _normalizeWebSocketUrl(String input) {
    final trimmed = input.trim();
    final uri = trimmed.contains('://') ? Uri.parse(trimmed) : Uri.parse('https://$trimmed');
    final scheme = uri.scheme == 'http' || uri.scheme == 'ws' ? 'ws' : 'wss';
    final port = uri.hasPort ? uri.port : (scheme == 'wss' ? 443 : 80);
    return Uri(scheme: scheme, host: uri.host, port: port, path: '/ws').toString();
  }

  Future<bool> _openConnection(String url) async {
    final uri = Uri.parse(url);
    final client = createTrustedHttpClient(allowedHost: uri.host);
    try {
      _channel = IOWebSocketChannel.connect(
        uri.toString(),
        customClient: client,
        headers: _currentCookie == null || _currentCookie!.isEmpty
            ? null
            : <String, dynamic>{'Cookie': _currentCookie!},
      );
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleChannelError,
        onDone: _handleChannelDone,
        cancelOnError: true,
      );
      _connected = true;
      _state['wifi'] = true;
      notifyListeners();
      return true;
    } catch (_) {
      client.close(force: true);
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    final text = message is String ? message : utf8.decode(message as List<int>);
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        _mergeState(decoded);
      } else {
        _state['message'] = text;
      }
    } catch (_) {
      _state['message'] = text;
    }
    _state['wifi'] = true;
    _connected = true;
    notifyListeners();
  }

  void _mergeState(Map<String, dynamic> decoded) {
    final type = decoded['type']?.toString();
    _state.addAll(decoded);

    if (type == 'check_result') {
      final checkList = _asMapList(_state['checkList']);
      checkList.add({
        'epc': decoded['epc'] ?? decoded['lastEpc'] ?? '',
        'result': decoded['result'] ?? '',
      });
      _state['checkList'] = checkList;
      _state['tag'] = decoded['epc'] ?? decoded['lastEpc'] ?? _state['tag'] ?? '';
      _state['tagDetecte'] = true;
    } else if (type == 'tags_batch') {
      final epcs = decoded['epcs'];
      if (epcs is List) {
        _state['batchList'] = epcs
            .map((value) => {'epc': value.toString()})
            .toList(growable: false);
      }
    } else if (type == 'save_result' || type == 'saveall_result') {
      if (decoded['message'] == null) {
        _state['message'] = decoded['status']?.toString() ?? decoded['result']?.toString() ?? '';
      }
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: true);
    }
    return <Map<String, dynamic>>[];
  }

  void _handleChannelError(Object error) {
    _setDisconnected();
    _scheduleReconnect();
  }

  void _handleChannelDone() {
    _setDisconnected();
    _scheduleReconnect();
  }

  void _setDisconnected() {
    _connected = false;
    _state['wifi'] = false;
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _currentUrl == null) return;
    _reconnectTimer?.cancel();
    final delaySeconds = (_reconnectAttempt < 5) ? (1 << _reconnectAttempt) : 16;
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_manualDisconnect || _currentUrl == null) return;
      await _openConnection(_currentUrl!);
      if (!_connected) {
        _scheduleReconnect();
      }
    });
  }

  void send(String message) {
    final sink = _channel?.sink;
    if (sink == null) return;

    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    switch (trimmed) {
      case 'CLEAR_CHECK':
        sink.add(jsonEncode({'action': 'clear_check'}));
        return;
      case 'CANCEL_SAVE':
        sink.add(jsonEncode({'action': 'cancel_save'}));
        return;
      case 'CLEAR_BATCH':
        sink.add(jsonEncode({'action': 'clear_batch'}));
        return;
      case 'SAVE_BATCH':
        sink.add(jsonEncode({'action': 'save_batch'}));
        return;
    }

    sink.add(trimmed);
  }

  void setMode(String mode) {
    final sink = _channel?.sink;
    if (sink == null) return;
    sink.add(jsonEncode({'action': 'set_mode', 'mode': mode}));
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;
    _disconnectInternal(notify: false);
    _connected = false;
    _state['wifi'] = false;
    notifyListeners();
  }

  Future<void> _disconnectInternal({required bool notify}) async {
    try {
      await _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (notify) {
      notifyListeners();
    }
  }
}