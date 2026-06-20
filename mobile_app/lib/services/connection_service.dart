import 'dart:async';
import 'package:flutter/foundation.dart';
import 'http_client.dart';

class ConnectionService extends ChangeNotifier {
  final String host; // e.g. https://192.168.4.1
  Timer? _timer;
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  ConnectionService({this.host = 'http://192.168.4.1'}) {
    startMonitoring();
  }

  void startMonitoring({Duration interval = const Duration(seconds: 5)}) {
    _timer?.cancel();
    // Immediate check
    _checkOnce();
    _timer = Timer.periodic(interval, (_) => _checkOnce());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkOnce() async {
    try {
      final uri = Uri.parse(host);
      final client = createTrustedHttpClient();

      final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      final response = await request.close().timeout(const Duration(seconds: 3));
      final ok = response.statusCode >= 200 && response.statusCode < 500;
      client.close(force: true);

      if (ok != _isConnected) {
        _isConnected = ok;
        notifyListeners();
      }
    } catch (e) {
      if (_isConnected != false) {
        _isConnected = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
