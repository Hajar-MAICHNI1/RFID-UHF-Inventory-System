// ✅ ALL imports at the TOP — fixes "directive_after_declaration"
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/http_client.dart';
import '../services/websocket_service.dart';
import '../services/esp_service.dart';
import 'admin/account_screen.dart';

// ─── Helper: trusted HTTP client from auth context ──────────
IOClient trustedClientFor(AuthService auth) {
  final ip = Uri.parse(auth.baseUrl).host;
  return createTrustedClient(allowedHost: ip);
}

// ════════════════════════════════════════════════════════════
// HOME SCREEN
// ════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late EspService _espService;

  @override
  void initState() {
    super.initState();
    // Initialize EspService for operateur real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeEspService();
    });
  }

  Future<void> _initializeEspService() async {
    if (!mounted) return;
    
    _espService = context.read<EspService>();
    final auth = context.read<AuthService>();
    
    // Connect to ESP32 WebSocket at 192.168.4.1 for real-time operateur updates
    // Using plain ws:// since HTTP is being used for API
    debugPrint('🔌 Initializing EspService WebSocket connection...');
    await _espService.connect('http://192.168.4.1', cookie: auth.sessionCookie);
  }

  @override
  void dispose() {
    _espService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, ws, _) {
        final state = ws.state;
        final mode  = state['mode'] ?? 'CHECK';

        return Scaffold(
          backgroundColor: const Color(0xFFf1f5f9),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 2,
            // FIX 3: title was a bare Row → overflows 50px on narrow screens.
            // Wrap the text label in Flexible so it clips gracefully.
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Hôtel RFID UHF',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Chip(
                  avatar: CircleAvatar(
                    backgroundColor:
                        ws.connected ? Colors.green : Colors.red,
                    radius: 6,
                  ),
                  label: Text(ws.connected ? 'Connecté' : 'Déconnecté'),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _StatusBar(state: state, wsConnected: ws.connected),
              if ((state['message'] ?? '').isNotEmpty)
                _AlertBanner(
                  message: state['message'] as String,
                  type: (state['msgType'] ?? '') as String,
                ),
              Expanded(
                child: _buildModeContent(context, mode, state, ws),
              ),
            ],
            ),
          // Show account FAB only in CHECK mode for quick operateur access
          floatingActionButton: mode == 'CHECK'
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AccountScreen()),
                    );
                  },
                  icon: const Icon(Icons.person),
                  label: const Text('Compte'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildModeContent(
    BuildContext ctx,
    String mode,
    Map<String, dynamic> state,
    WebSocketService ws,
  ) {
    switch (mode) {
      case 'SAVE':
        return _SaveModeWidget(state: state, ws: ws);
      case 'SAVEALL':
        return _SaveAllModeWidget(state: state, ws: ws);
      default:
        return _CheckModeWidget(state: state, ws: ws);
    }
  }
}

// ════════════════════════════════════════════════════════════
// STATUS BAR
// ════════════════════════════════════════════════════════════
class _StatusBar extends StatelessWidget {
  final Map<String, dynamic> state;
  final bool wsConnected;
  const _StatusBar({required this.state, required this.wsConnected});

  @override
  Widget build(BuildContext context) {
    final mode  = (state['mode']  ?? 'CHECK') as String;
    final relay = (state['relay'] ?? false) as bool;

    final modeColor = {
      'CHECK':   Colors.blue,
      'SAVE':    Colors.orange,
      'SAVEALL': Colors.purple,
    }[mode] ?? Colors.grey;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Pill(
              label: wsConnected ? 'LIEN ESP32' : 'LIEN ESP32',
              icon: wsConnected ? Icons.check_circle : Icons.error,
              color: wsConnected ? Colors.green.shade100 : Colors.red.shade100,
              textColor: wsConnected ? Colors.green.shade800 : Colors.red.shade800,
            ),
            const SizedBox(width: 8),
            _Pill(
              label: mode,
              icon: Icons.tune,
              color: modeColor.withValues(alpha: 0.15),
              textColor: modeColor,
            ),
            const SizedBox(width: 8),
            _Pill(
              label: relay ? 'OUVERT' : 'FERME',
              icon: relay ? Icons.lock_open : Icons.lock,
              color: relay ? Colors.green.shade100 : Colors.grey.shade200,
              textColor: relay ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color, textColor;
  final IconData icon;
  const _Pill(
      {required this.label,
      required this.icon,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════
// ALERT BANNER
// ════════════════════════════════════════════════════════════
class _AlertBanner extends StatelessWidget {
  final String message, type;
  const _AlertBanner({required this.message, required this.type});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: type == 'ok'
              ? Colors.green.shade100
              : Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: type == 'ok' ? Colors.green : Colors.red,
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: type == 'ok'
                ? Colors.green.shade800
                : Colors.red.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════
// CHECK MODE - Enhanced with Theft Detection
// ════════════════════════════════════════════════════════════
class _CheckModeWidget extends StatefulWidget {
  final Map<String, dynamic> state;
  final WebSocketService ws;
  const _CheckModeWidget({required this.state, required this.ws});

  @override
  State<_CheckModeWidget> createState() => _CheckModeState();
}

class _CheckModeState extends State<_CheckModeWidget> {
  @override
  void didUpdateWidget(_CheckModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detect new theft alerts (FOUND at door)
    final newCheckList = List<Map<String, dynamic>>.from(
        (widget.state['checkList'] as List?)?.map((e) =>
                Map<String, dynamic>.from(e as Map)) ??
            []);
    final oldCheckList = List<Map<String, dynamic>>.from(
        (oldWidget.state['checkList'] as List?)?.map((e) =>
                Map<String, dynamic>.from(e as Map)) ??
            []);
    
    if (newCheckList.length > oldCheckList.length) {
      final latest = newCheckList.last;
      final result = (latest['result'] ?? '') as String;
      
      // FOUND = Theft detected!
      if (result.startsWith('FOUND')) {
        _showTheftAlert(context, latest);
      }
    }
  }

  void _showTheftAlert(BuildContext context, Map<String, dynamic> alert) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade300,
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      size: 48, color: Colors.red),
                ),
                const SizedBox(height: 16),
                const Text(
                  '🚨 VOL DÉTECTÉ!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Article trouvé à la porte!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'EPC: ${alert['epc'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = List<Map<String, dynamic>>.from(
        (widget.state['checkList'] as List?)?.map((e) =>
                Map<String, dynamic>.from(e as Map)) ??
            []);

    return Column(
      children: [
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📡', style: TextStyle(fontSize: 64)),
                      SizedBox(height: 16),
                      Text(
                        'En attente de tags RFID…',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Chaque tag sera vérifié automatiquement',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final item = list[i];
                    final result = (item['result'] ?? '') as String;
                    
                    // ESP32 Logic: FOUND = THEFT (red), NOT_FOUND = OK (green)
                    final isTheft = result.startsWith('FOUND');
                    final typeName = isTheft
                        ? result.contains('|') ? result.split('|')[1] : 'Article'
                        : 'AUTORISÉ';
                    final label = isTheft
                        ? '🚨 VOL: $typeName'
                        : '✅ Aucun problème';
                    final bgColor = isTheft
                        ? Colors.red.shade100
                        : Colors.green.shade100;
                    final textColor = isTheft
                        ? Colors.red.shade800
                        : Colors.green.shade800;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isTheft ? 4 : 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isTheft ? Colors.red : Colors.green,
                            width: 2,
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            isTheft ? Icons.warning_amber : Icons.check_circle,
                            color: textColor,
                            size: 28,
                          ),
                          title: Text(
                            (item['epc'] ?? '') as String,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 13),
                          ),
                          subtitle: Text(
                            isTheft ? 'Alerte de sécurité!' : 'Passage autorisé',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Chip(
                            label: Text(label),
                            backgroundColor: bgColor,
                            labelStyle: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () => widget.ws.send('CLEAR_CHECK'),
              icon: const Icon(Icons.delete),
              label: const Text("Effacer l'historique"),
            ),
          ),
      ],
    );
  }
}
// SAVE MODE
// ════════════════════════════════════════════════════════════
class _SaveModeWidget extends StatefulWidget {
  final Map<String, dynamic> state;
  final WebSocketService ws;
  const _SaveModeWidget({required this.state, required this.ws});

  @override
  State<_SaveModeWidget> createState() => _SaveModeState();
}

class _SaveModeState extends State<_SaveModeWidget> {
  String? _selectedType;
  bool _saving = false;

  Future<void> _save() async {
    if (_selectedType == null) return;
    setState(() => _saving = true);

    final auth   = context.read<AuthService>();
    final client = trustedClientFor(auth);
    final epc    = (widget.state['tag'] ?? '') as String;

    try {
      final response = await client.post(
        Uri.parse('${auth.baseUrl}/save'),
        headers: {
          ...auth.authHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'epc=$epc&type_numero=$_selectedType',
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        widget.ws.send('CANCEL_SAVE');
      } else {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tag      = (widget.state['tag'] ?? '') as String;
    final detected = (widget.state['tagDetecte'] ?? false) as bool;
    final types    = List<Map<String, dynamic>>.from(
        (widget.state['types'] as List?)?.map(
                (e) => Map<String, dynamic>.from(e as Map)) ??
            []);

    if (!detected || tag.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏷️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'Présentez un tag RFID…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Le formulaire apparaîtra automatiquement',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: Colors.amber.shade600, width: 6),
              ),
            ),
            child: const Text(
              '✨ Tag détecté !',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: "Type d'objet",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label),
            ),
            initialValue: _selectedType,
            items: types
                .map((t) => DropdownMenuItem<String>(
                      value: t['num'].toString(),
                      child: Text(t['nom'].toString()),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedType = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_saving || _selectedType == null) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '💾 Enregistrer',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.ws.send('CANCEL_SAVE'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('✖ Annuler',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SAVEALL MODE
// ════════════════════════════════════════════════════════════
class _SaveAllModeWidget extends StatelessWidget {
  final Map<String, dynamic> state;
  final WebSocketService ws;
  const _SaveAllModeWidget({required this.state, required this.ws});

  @override
  Widget build(BuildContext context) {
    final list     = List<String>.from((state['batchList'] as List?) ?? []);
    final pending  = (state['batchPending'] ?? false) as bool;
    final timeLeft = (state['timeLeft'] ?? 0) as int;
    final result   = (state['batchResult'] ?? '') as String;

    if (result.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✅', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text(
                'Enregistrement terminé !',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ws.send('CLEAR_BATCH'),
                child: const Text('↩️ Nouveau lot'),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📦', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'Présentez les tags RFID…',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Ils seront ajoutés au lot automatiquement',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '${list.length}',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7c3aed),
            ),
          ),
        ),
        const Text('tags collectés',
            style: TextStyle(color: Colors.grey)),
        if (pending && timeLeft > 0) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.yellow.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                  left: BorderSide(color: Colors.amber, width: 4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Enregistrement auto dans',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${timeLeft}s',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '● ${list[i]}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFF4c1d95),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => ws.send('SAVE_BATCH'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7c3aed),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '💾 Enregistrer maintenant',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ws.send('CLEAR_BATCH'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('🗑️ Vider le lot',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}