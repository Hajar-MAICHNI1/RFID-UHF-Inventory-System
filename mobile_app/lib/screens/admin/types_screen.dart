import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/http_client.dart';

class TypesScreen extends StatefulWidget {
  const TypesScreen({super.key});

  @override
  State<TypesScreen> createState() => _TypesScreenState();
}

class _TypesScreenState extends State<TypesScreen> {
  List<Map<String, dynamic>> _types = [];
  bool _loading = true;
  String _search = '';
  Timer? _refreshTimer;

  static const Color _navyBlue = Color(0xFF0A3C6F);
  static const Color _lightBlue = Color(0xFF6EA1D4);
  static const Color _tealGreen = Color(0xFF168D8C);

  @override
  void initState() {
    super.initState();
    _loadTypes();
    // Removed auto-refresh - now only manual refresh via button
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    if (!mounted) return;
    
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthService>();

      debugPrint('═══ LOADING TYPES ═══');
      debugPrint('📍 Using server URL: ${auth.dataBaseUrl}');

      final base = Uri.parse(auth.dataBaseUrl);
      final typesUri = base.replace(path: '/Reader/get_types.php');
      debugPrint('Requesting: $typesUri');

      final client = createTrustedClient(allowedHost: base.host);

      try {
        final response = await client.get(
          typesUri,
          headers: {
            'Cookie': auth.sessionCookie ?? '',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));

        debugPrint('Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          // Parse pipe-separated format: "1|Type1,2|Type2,..."
          final types = _parseTypes(response.body);
          if (mounted) {
            setState(() {
              _types = types;
              _loading = false;
            });
          }
          debugPrint('✅ Loaded ${_types.length} types');
          return;
        }
      } on HandshakeException catch (e) {
        debugPrint('⚠️ HTTPS handshake failed: $e, trying HTTP fallback...');
        final httpUri = typesUri.replace(scheme: 'http', port: 80);
        final clientHttp = createTrustedClient(allowedHost: base.host);
        try {
          final response = await clientHttp.get(
            httpUri,
            headers: {
              'Cookie': auth.sessionCookie ?? '',
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final types = _parseTypes(response.body);
            if (mounted) {
              setState(() {
                _types = types;
                _loading = false;
              });
            }
            debugPrint('✅ Loaded ${_types.length} types (HTTP)');
            return;
          }
        } finally {
          clientHttp.close();
        }
      } finally {
        client.close();
      }

      if (mounted) {
        setState(() => _loading = false);
      }
      _showError('Impossible de charger les types');
    } catch (e) {
      debugPrint('❌ Error loading types: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
      _showError('Erreur: $e');
    }
  }

  List<Map<String, dynamic>> _parseTypes(String response) {
    try {
      List<Map<String, dynamic>> types = [];
      final parts = response.split(',');
      for (var part in parts) {
        final vals = part.trim().split('|');
        if (vals.length == 2) {
          types.add({
            'numero': int.tryParse(vals[0]) ?? 0,
            'nom_type': vals[1],
          });
        }
      }
      return types;
    } catch (e) {
      debugPrint('Parse error: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> get _filteredTypes {
    if (_search.isEmpty) return _types;
    return _types.where((t) {
      final nom = (t['nom_type'] ?? '').toString().toLowerCase();
      return nom.contains(_search.toLowerCase());
    }).toList();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _tealGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addType() async {
    final TextEditingController nomController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un nouveau type'),
        content: TextField(
          controller: nomController,
          decoration: InputDecoration(
            hintText: 'Nom du type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nom = nomController.text.trim();
              if (nom.isEmpty) {
                _showError('Le nom du type est requis');
                return;
              }
              Navigator.pop(ctx);
              await _submitAddType(nom);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealGreen,
            ),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAddType(String nomType) async {
    try {
      final auth = context.read<AuthService>();
      final base = Uri.parse(auth.dataBaseUrl);
      final addUri = base.replace(path: '/Reader/add_type.php');

      final client = createTrustedClient(allowedHost: base.host);

      try {
        final response = await client.post(
          addUri,
          headers: {
            'Cookie': auth.sessionCookie ?? '',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'nom_type': nomType}),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            _showSuccess('Type ajouté avec succès');
            await _loadTypes();
            return;
          }
        }
        _showError(response.body);
      } finally {
        client.close();
      }
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  Future<void> _editType(Map<String, dynamic> type) async {
    final TextEditingController nomController = TextEditingController(
      text: type['nom_type'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le type'),
        content: TextField(
          controller: nomController,
          decoration: InputDecoration(
            hintText: 'Nom du type',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nom = nomController.text.trim();
              if (nom.isEmpty) {
                _showError('Le nom du type est requis');
                return;
              }
              Navigator.pop(ctx);
              await _submitEditType(type['numero'], nom);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _tealGreen,
            ),
            child: const Text('Modifier', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEditType(int numero, String nomType) async {
    try {
      final auth = context.read<AuthService>();
      final base = Uri.parse(auth.dataBaseUrl);
      final editUri = base.replace(path: '/Reader/edit_type.php');

      final client = createTrustedClient(allowedHost: base.host);

      try {
        final response = await client.post(
          editUri,
          headers: {
            'Cookie': auth.sessionCookie ?? '',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'numero': numero,
            'nom_type': nomType,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            _showSuccess('Type modifié avec succès');
            await _loadTypes();
            return;
          }
        }
        _showError(response.body);
      } finally {
        client.close();
      }
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  Future<void> _deleteType(Map<String, dynamic> type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le type'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${type['nom_type']}"?\n\n⚠️ Cela n\'affectera pas les tags existants.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitDeleteType(type['numero']);
    }
  }

  Future<void> _submitDeleteType(int numero) async {
    try {
      final auth = context.read<AuthService>();
      final base = Uri.parse(auth.dataBaseUrl);
      final deleteUri = base.replace(path: '/Reader/delete_type.php');

      final client = createTrustedClient(allowedHost: base.host);

      try {
        final response = await client.post(
          deleteUri,
          headers: {
            'Cookie': auth.sessionCookie ?? '',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'numero': numero}),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            _showSuccess('Type supprimé avec succès');
            await _loadTypes();
            return;
          }
        }
        _showError(response.body);
      } finally {
        client.close();
      }
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('📋 Gestion des Types'),
        backgroundColor: _navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTypes,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with search and add button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _search = val),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un type...',
                      prefixIcon: const Icon(Icons.search, color: _lightBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _lightBlue),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  onPressed: _addType,
                  backgroundColor: _tealGreen,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          // Types list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _tealGreen),
                  )
                : _filteredTypes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 80,
                              color: _lightBlue.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _search.isEmpty
                                  ? 'Aucun type trouvé'
                                  : 'Aucun type correspondant',
                              style: const TextStyle(
                                color: _lightBlue,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTypes.length,
                        itemBuilder: (ctx, idx) {
                          final type = _filteredTypes[idx];
                          return _buildTypeCard(type);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(Map<String, dynamic> type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _tealGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '#${type['numero']}',
              style: const TextStyle(
                color: _tealGreen,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          type['nom_type'] ?? 'Sans nom',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: _navyBlue,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: _tealGreen),
              onPressed: () => _editType(type),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteType(type),
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }
}
