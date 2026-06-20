import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../services/auth_service.dart';
import '../../services/http_client.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});
  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  List<Map<String, dynamic>> _tags = [];
  bool _loading = true;
  String _search = '';
  Timer? _refreshTimer;

  static const Color _navyBlue = Color(0xFF0A3C6F);
  static const Color _lightBlue = Color(0xFF6EA1D4);

  @override
  void initState() {
    super.initState();
    _loadTags();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadTags(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() {
      _loading = true;
      _tags = [];
    });

    try {
      final auth = context.read<AuthService>();
      
      debugPrint('═══ LOADING TAGS ═══');
      debugPrint('📍 Using server URL: ${auth.dataBaseUrl}');
      debugPrint('🍪 Session cookie: ${auth.sessionCookie}');
      
      final base = Uri.parse(auth.dataBaseUrl);
      final tagsUri = base.replace(path: '/Reader/get_tags.php');
      debugPrint('1️⃣ Requesting: $tagsUri');

      // Create HTTP client trusting the configured server
      final client = createTrustedClient(allowedHost: base.host);
      late final int statusCode;
      late final String bodyStr;
      String? contentType;
      
      try {
        final response = await client.get(
          tagsUri,
          headers: {
            'Cookie': auth.sessionCookie ?? '',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        statusCode = response.statusCode;
        bodyStr = response.body;
        contentType = response.headers['content-type'];
      } on HandshakeException catch (e) {
        debugPrint('   ⚠️ HTTPS handshake failed: $e');
        debugPrint('   ↪️ Trying HTTP fallback...');
        final httpUri = tagsUri.replace(scheme: 'http', port: 80);
        final clientHttp = createTrustedClient(allowedHost: base.host);
        try {
          final response = await clientHttp.get(
            httpUri,
            headers: {
              'Cookie': auth.sessionCookie ?? '',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));
          statusCode = response.statusCode;
          bodyStr = response.body;
          contentType = response.headers['content-type'];
        } finally {
          clientHttp.close();
        }
      } finally {
        client.close();
      }

      debugPrint('   Status: $statusCode');
      debugPrint('   Content-Type: $contentType');

      final preview = bodyStr.length > 200 ? bodyStr.substring(0, 200) : bodyStr;
      debugPrint('   Response: $preview');

      // Check if we got JSON
      if (statusCode == 200 && (bodyStr.startsWith('{') || bodyStr.startsWith('['))) {
        debugPrint('   ✅ Got JSON!');
        final data = jsonDecode(bodyStr);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _tags = List<Map<String, dynamic>>.from(
                (data['tags'] as List).map((e) => Map<String, dynamic>.from(e as Map))
              );
            });
          }
          debugPrint('   ✅ Loaded ${_tags.length} tags');
          if (mounted) {
            setState(() => _loading = false);
          }
          return;
        }
      }

      debugPrint('   ❌ Server returned non-JSON or error. Status: $statusCode');
      
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      
    } catch (e) {
      debugPrint('❌ Error loading tags: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTags {
    if (_search.isEmpty) return _tags;
    return _tags.where((t) {
      final epc = (t['epc'] ?? '').toString().toLowerCase();
      final type = (t['nom_type'] ?? '').toString().toLowerCase();
      return epc.contains(_search.toLowerCase()) ||
          type.contains(_search.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('🗄️ Base de données'),
        backgroundColor: const Color(0xFF0A3C6F),
        foregroundColor: const Color(0xFFF5DCAD),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTags,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par EPC ou type...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.grey.shade200, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: _navyBlue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _navyBlue.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.label, size: 16, color: _navyBlue),
                      const SizedBox(width: 6),
                      Text(
                        '${_filteredTags.length} tags',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _navyBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tags list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tags.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: _navyBlue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.storage,
                                  size: 64, color: Color(0xFFD0D0D0)),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Aucun tag enregistré',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Les tags apparaîtront ici après\nleur première lecture',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: _filteredTags.length,
                        itemBuilder: (_, i) {
                          final tag = _filteredTags[i];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          _lightBlue.withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color:
                                              _lightBlue.withValues(alpha: 0.3),
                                          width: 1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${(tag['id'] ?? i + 1)}',
                                        style: const TextStyle(
                                            color: _navyBlue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tag['epc'] ?? '—',
                                          style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade800),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tag['nom_type'] ?? 'Type inconnu',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              tag['created_at'] != null
                                                  ? tag['created_at'].toString().split(' ')[0]
                                                  : '—',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade400),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}