import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class DebugAuthScreen extends StatefulWidget {
  const DebugAuthScreen({super.key});

  @override
  State<DebugAuthScreen> createState() => _DebugAuthScreenState();
}

class _DebugAuthScreenState extends State<DebugAuthScreen> {
  String _output = '';
  bool _loading = false;

  Future<void> _testTags() async {
    setState(() { _loading = true; _output = ''; });
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    api.setSessionCookie(auth.sessionCookie);

    final res = await api.getTags();
    setState(() {
      _output = res.toString();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Auth & Proxy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ESP URL (login): ${auth.espBaseUrl}'),
            const SizedBox(height: 4),
            Text('Server URL (data): ${auth.dataBaseUrl}'),
            const SizedBox(height: 8),
            Text('Session cookie: ${auth.sessionCookie == null ? "<none>" : "present (${auth.sessionCookie!.length} chars)"}'),
            const SizedBox(height: 4),
            Text(
              auth.sessionCookie == null || auth.sessionCookie!.isEmpty
                  ? 'Status: Not authenticated. Log in first, then retry.'
                  : 'Status: Authenticated',
              style: TextStyle(
                color: auth.sessionCookie == null || auth.sessionCookie!.isEmpty ? Colors.red : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _testTags,
              child: _loading ? const CircularProgressIndicator() : const Text('Call /Reader/get_tags via app'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(_output.isEmpty ? 'No output yet' : _output),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
