import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

const String _defaultHost = '172.25.236.59'; 
const int _port = 3000;

String get apiBaseUrl {
  if (kIsWeb) return 'http://localhost:3000';

  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:$_port';
    if (Platform.isIOS) return 'http://localhost:$_port';
  } catch (_) {}

  return 'http://$_defaultHost:$_port';
}
