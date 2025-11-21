import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

const int _port = 3000;
String? _cachedServerIp;

// List of common local network IP patterns to try
const List<String> _commonIpPrefixes = [
  '192.168.1',
  '192.168.0',
  '192.168.47',
  '192.168.57',
  '10.0.0',
  '10.0.2', // Android emulator
];

/// Get the server IP dynamically
Future<String> getServerIp() async {
  // Return cached IP if available
  if (_cachedServerIp != null) {
    return _cachedServerIp!;
  }

  // For web, always use localhost
  if (kIsWeb) {
    _cachedServerIp = 'localhost';
    return _cachedServerIp!;
  }

  // For Android emulator
  try {
    if (Platform.isAndroid) {
      // Try 10.0.2.2 first (Android emulator host)
      if (await _testConnection('10.0.2.2')) {
        _cachedServerIp = '10.0.2.2';
        return _cachedServerIp!;
      }
    }
  } catch (_) {}

  // Try localhost first (fastest for same machine)
  if (await _testConnection('localhost')) {
    _cachedServerIp = 'localhost';
    return _cachedServerIp!;
  }

  // Try to fetch server IP from common patterns (parallel for speed)
  final futures = <Future<String?>>[];
  for (final prefix in _commonIpPrefixes) {
    for (int i = 1; i <= 5; i++) {
      final testIp = '$prefix.$i';
      futures.add(_testConnection(testIp).then((success) => success ? testIp : null));
    }
  }

  final results = await Future.wait(futures);
  for (final ip in results) {
    if (ip != null) {
      _cachedServerIp = ip;
      return _cachedServerIp!;
    }
  }

  // Fallback to localhost
  _cachedServerIp = 'localhost';
  return _cachedServerIp!;
}

/// Test if server is reachable at given IP
Future<bool> _testConnection(String ip) async {
  try {
    final response = await http
        .get(Uri.parse('http://$ip:$_port/server-ip'))
        .timeout(const Duration(milliseconds: 300));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Clear cached IP (useful for network changes)
void clearCachedIp() {
  _cachedServerIp = null;
}

String get apiBaseUrl {
  if (kIsWeb) return 'http://localhost:$_port';
  
  // Return cached IP if available, otherwise return placeholder
  // The app should call getServerIp() on startup to populate this
  final ip = _cachedServerIp ?? 'localhost';
  return 'http://$ip:$_port';
}
