import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  static const Color _navyBlue = Color(0xFF0A3C6F);
  static const Color _gold = Color(0xFFCD9538);
  static const Color _teal = Color(0xFF168D8C);

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadStats(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Convert by_type Map into List of widgets
  List<Widget> _buildTypesList() {
    if (_stats == null) return [];

    final byType = _stats!['by_type'];

    final entries = <MapEntry<String, dynamic>>[];

    if (byType is Map) {
      byType.forEach((key, value) {
        entries.add(MapEntry(key.toString(), value));
      });
    } else if (byType is List) {
      for (final item in byType) {
        if (item is Map) {
          final rawName = item['nom_type'] ?? item['name'] ?? item['type'] ?? item['label'];
          final rawCount = item['count'] ?? item['total'] ?? item['value'];
          final name = (rawName ?? 'Type inconnu').toString();
          entries.add(MapEntry(name, rawCount ?? 0));
        }
      }
    }

    if (entries.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Aucune donnée',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          ),
        ),
      ];
    }

    return entries
        .map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.label,
                            size: 20, color: _teal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _teal.withValues(alpha: 0.2),
                              _teal.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _teal.withValues(alpha: 0.3),
                              width: 1),
                        ),
                        child: Text(
                          '${entry.value ?? 0}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _teal),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ))
        .toList();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    debugPrint('═══ LOADING STATISTICS ═══');
    debugPrint('📍 Using server URL: ${auth.dataBaseUrl}');
    debugPrint('🍪 Session cookie: ${auth.sessionCookie}');
    
    final api = context.read<ApiService>();
    api.setSessionCookie(auth.sessionCookie);

    final cachedStats = api.cachedStats;
    if (cachedStats != null) {
      debugPrint('⚡ Showing cached stats immediately');
      if (mounted) {
        setState(() {
          _stats = cachedStats;
          _loading = false;
          _error = null;
        });
      }
      // Refresh in the background, but keep the cached data visible.
      api.prefetchStats();
      return;
    }

    // Retry with exponential backoff for intermittent TLS handshake failures.
    Map<String, dynamic> stats = {'error': 'Unknown error'};
    const int maxAttempts = 2;
    int attempt = 0;
    while (attempt < maxAttempts) {
      try {
        stats = await api.getStats();
        // If successful (no error key) break early
        if (!stats.containsKey('error')) break;
        debugPrint('Attempt ${attempt + 1} returned error: ${stats['error']}');
      } catch (e) {
        debugPrint('Attempt ${attempt + 1} exception: $e');
      }

      attempt++;
      // modest backoff: 500ms, 1000ms
      await Future.delayed(Duration(milliseconds: 500 * (1 << (attempt - 1))));
    }

    if (mounted) {
      setState(() {
        if (stats.containsKey('error')) {
          _error = stats['error'];
          _stats = {
            'total_tags': 0,
            'unknown_today': 0,
            'unread_alerts': 0,
            'by_type': [],
          };
          debugPrint('❌ Stats error: ${stats['error']}');
        } else {
          _stats = stats;
          debugPrint('✅ Loaded stats: ${stats.keys.join(', ')}');
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('📊 Statistiques'),
        backgroundColor: const Color(0xFF0A3C6F),
        foregroundColor: const Color(0xFFF5DCAD),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadStats),
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
                        onPressed: _loadStats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  children: [
                    Row(children: [
                      Expanded(
                          child: _StatCard(
                        title: 'Total Tags',
                        value: '${_stats!['total_tags'] ?? 0}',
                        icon: Icons.label,
                        color: _teal,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                        title: "Alertes aujourd'hui",
                        value: '${_stats!['today_alerts'] ?? _stats!['unknown_today'] ?? 0}',
                        icon: Icons.warning,
                        color: _gold,
                      )),
                    ]),
                    const SizedBox(height: 20),
                    _StatCard(
                      title: 'Alertes non lues',
                      value: '${_stats!['unread_alerts'] ?? 0}',
                      icon: Icons.notifications_active,
                      color: _navyBlue,
                    ),
                    const SizedBox(height: 32),
                    // Section Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, size: 20, color: _teal),
                          const SizedBox(width: 8),
                          Text(
                            'Tags par type',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 3,
                      width: 50,
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildTypesList(),
                  ],
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 8,
        shadowColor: color.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 36),
                ),
                const SizedBox(height: 12),
                Text(value,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}