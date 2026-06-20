import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'services/esp_service.dart';
import 'services/connection_service.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        // ApiService will load its base_url from SharedPreferences after login
        ChangeNotifierProvider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProvider<WebSocketService>(
            create: (_) => WebSocketService()),
        // New EspService for operateur real-time WebSocket updates
        ChangeNotifierProvider<EspService>(
            create: (_) => EspService()),
        ChangeNotifierProvider<ConnectionService>(
            create: (_) => ConnectionService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  bool? _lastConnected;
  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _listenerAttached) return;
      final conn = context.read<ConnectionService>();
      conn.addListener(_onConnChange);
      _listenerAttached = true;
      _lastConnected ??= conn.isConnected;
    });
  }

  void _onConnChange() {
    final conn = context.read<ConnectionService>();
    final isConnected = conn.isConnected;
    if (_lastConnected == null) {
      _lastConnected = isConnected;
      return;
    }

    if (_lastConnected == true && isConnected == false) {
      // lost connection: intentionally silent (no user notification)
      debugPrint('Connection to ESP lost — notification suppressed');
    } else if ((_lastConnected == false || _lastConnected == null) && isConnected == true) {
      // restored
      _scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('✅ Connexion à l\'ESP rétablie'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    _lastConnected = isConnected;
  }

  @override
  void dispose() {
    try {
      context.read<ConnectionService>().removeListener(_onConnChange);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Hôtel RFID',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a2f5e),
        ),
        primaryColor: const Color(0xFF1a2f5e),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer navigation to after build phase completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    final auth = context.read<AuthService>();    
    // Clear session state (don't make network call on startup)
    // This prevents stale/expired sessions from bypassing login.
    auth.clearSession();
    
    if (!mounted) return;
    
    // Always go to login on app startup.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}