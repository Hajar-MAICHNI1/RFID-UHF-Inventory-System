import 'dart:io';
import 'package:http/io_client.dart';
import 'esp32_cert.dart';

/// Creates an HTTP client that trusts the app-embedded ESP32 certificate
/// (from `esp32_cert.dart`) so TLS handshakes succeed with the ESP32's
/// self-signed cert on the local LAN.
HttpClient createTrustedHttpClient({String? allowedHost}) {
  final securityContext = SecurityContext(withTrustedRoots: false);
  // Load the ESP32 certificate bytes into the context so the handshake
  // can complete using that cert as a trusted root.
  try {
    securityContext.setTrustedCertificatesBytes(esp32CertPem);
  } catch (_) {
    // Some platforms may not allow setting certs; fallback will still use
    // badCertificateCallback below to allow connections in development.
  }
  securityContext.allowLegacyUnsafeRenegotiation = true;

  final httpClient = HttpClient(context: securityContext)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (allowedHost != null) return host == allowedHost;
      if (host == 'localhost' || host == '127.0.0.1') return true;
      if (host.startsWith('192.168.')) return true;
      if (host.startsWith('10.')) return true;
      final re172 = RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.');
      if (re172.hasMatch(host)) return true;
      return false;
    };

  return httpClient;
}

IOClient createTrustedClient({String? allowedHost}) {
  final httpClient = createTrustedHttpClient(allowedHost: allowedHost);
  return IOClient(httpClient);
}