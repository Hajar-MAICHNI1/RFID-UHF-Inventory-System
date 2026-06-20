import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;
  Timer? _refreshTimer;

  static const Color _teal = Color(0xFF168D8C);
  static const Color _red = Color(0xFFE84C3D);

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadAlerts(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    debugPrint('═══ LOADING ALERTS ═══');
    debugPrint('📍 Using server URL: ${auth.dataBaseUrl}');
    debugPrint('🍪 Session cookie: ${auth.sessionCookie}');
    
    final api = context.read<ApiService>();
    api.setSessionCookie(auth.sessionCookie);

    try {
      final result = await api.getAlerts(limit: 100);

      if (mounted) {
        setState(() {
          if (result.containsKey('error') && result['error'] != null) {
            _error = result['error'];
            _alerts = [];
            _unreadCount = 0;
            debugPrint('❌ Alerts error: ${result['error']}');
          } else {
            _alerts = List<Map<String, dynamic>>.from(result['alerts'] ?? []);
            _unreadCount = result['unread_count'] ?? 0;
            debugPrint('✅ Loaded ${_alerts.length} alerts, $_unreadCount unread');
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading alerts: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _alerts = [];
          _unreadCount = 0;
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(int index) async {
    if (index < 0 || index >= _alerts.length) return;

    final alert = _alerts[index];
    final alertId = alert['id'] as int?;
    if (alertId == null) return;

    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    api.setSessionCookie(auth.sessionCookie);

    final success = await api.markAlertAsRead(alertId);
    if (success && mounted) {
      setState(() {
        _alerts[index]['is_read'] = 1;
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
      });
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer toutes les alertes ?'),
        content: const Text(
            'Cette action supprimera toutes les alertes de vol enregistrées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final auth = context.read<AuthService>();
      final api = context.read<ApiService>();
      api.setSessionCookie(auth.sessionCookie);

      final success = await api.clearAllAlerts();
      if (success && mounted) {
        setState(() {
          _alerts.clear();
          _unreadCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Alertes effacées')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: _unreadCount > 0
            ? Text('🔔 Alertes ($_unreadCount non lues)',
                style: const TextStyle(color: Color(0xFFF5DCAD)))
            : const Text('🔔 Alertes',
                style: TextStyle(color: Color(0xFFF5DCAD))),
        backgroundColor: const Color(0xFF168D8C),
        foregroundColor: const Color(0xFFF5DCAD),
        actions: [
          if (_alerts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Effacer tout',
              onPressed: _clearAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Erreur de chargement',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadAlerts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: _teal.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_outline,
                                size: 64, color: _teal),
                          ),
                          const SizedBox(height: 24),
                          const Text('Aucune alerte !',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun vol détecté\nà la porte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAlerts,
                      color: _teal,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        itemCount: _alerts.length,
                        itemBuilder: (_, i) {
                          final alert = _alerts[i];
                          final isRead =
                              alert['is_read'] == 1 || alert['is_read'] == true;
                          final epc = alert['epc'] ?? 'Unknown EPC';
                          final timestamp = alert['timestamp'] ?? '';
                          final type = alert['type'] ?? 'THEFT';

                          return Card(
                            elevation: isRead ? 2 : 4,
                            shadowColor:
                                _red.withValues(alpha: isRead ? 0.1 : 0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isRead
                                ? Colors.white
                                : _red.withValues(alpha: 0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isRead ? Colors.grey : _red)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                        isRead
                                            ? Icons.check_circle
                                            : Icons.warning_amber,
                                        color: isRead ? Colors.grey : _red,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          epc,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  Colors.grey.shade800,
                                              fontFamily: 'monospace'),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          type == 'THEFT'
                                              ? '🚨 Vol détecté à la porte'
                                              : 'Alerte de sécurité',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600),
                                        ),
                                        if (timestamp.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            timestamp,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (!isRead)
                                    IconButton(
                                      icon: const Icon(Icons.check),
                                      iconSize: 20,
                                      color: _red,
                                      onPressed: () => _markAsRead(i),
                                      tooltip: 'Marquer comme lu',
                                    )
                                  else
                                    Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: Colors.green.shade600,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}