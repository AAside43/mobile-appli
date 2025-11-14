import 'dart:io' show Platform;

/// Centralized API base URL for this project.
///
/// Behavior:
/// - Android emulator (recommended for local dev): returns http://10.0.2.2:3000
/// - iOS simulator: returns http://localhost:3000
/// - Other platforms / physical devices: returns http://172.25.87.158:3000 (project's host)
///
/// If you run the backend on a different host or port, edit `_defaultHost` / `_port` below.
const String _defaultHost = '172.25.87.158';
const int _port = 3000;

String get apiBaseUrl {
  // Use try/catch because Platform may not be available on all targets (web).
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:$_port';
    if (Platform.isIOS) return 'http://localhost:$_port';
  } catch (_) {
    // ignore - fall back to default
  }
  return 'http://$_defaultHost:$_port';
}
