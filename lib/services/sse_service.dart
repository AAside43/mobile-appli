import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Lightweight SSE client implemented using http.Client and stream parsing.
/// - Reconnects with exponential backoff on errors.
/// - Emits parsed events as Map<String, dynamic>: { 'event': name, 'data': payload }
class SseService {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;

  http.Client? _client;
  StreamSubscription<String>? _lineSub;
  bool _isConnecting = false;
  bool _isDisposed = false;

  // Reconnect/backoff state
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  Future<void> connect() async {
    if (_isDisposed) return;
    if (_isConnecting) return;
    _isConnecting = true;

    // reset any previous backoff
    _reconnectTimer?.cancel();
    _reconnectAttempt = 0;

    await _startConnection();
    _isConnecting = false;
  }

  Future<void> _startConnection() async {
    _client?.close();
    _client = http.Client();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse('$apiBaseUrl/events');
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamed =
          await _client!.send(request).timeout(const Duration(seconds: 10));

      if (streamed.statusCode != 200) {
        _controller.add({
          'event': 'sse_error',
          'data': {'status': streamed.statusCode}
        });
        _scheduleReconnect();
        return;
      }

      // parse lines and build events
      final lineStream = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      String? eventName;
      final StringBuffer dataBuffer = StringBuffer();

      _lineSub = lineStream.listen((line) {
        // SSE comments
        if (line.isEmpty) {
          // dispatch
          final raw = dataBuffer.toString();
          dynamic payload = raw;
          try {
            payload = jsonDecode(raw);
          } catch (_) {
            // leave as string if not JSON
          }
          _controller.add({'event': eventName ?? 'message', 'data': payload});
          // reset
          eventName = null;
          dataBuffer.clear();
          return;
        }

        if (line.startsWith(':')) {
          // comment / keepalive
          return;
        }

        final idx = line.indexOf(':');
        String field, value;
        if (idx == -1) {
          field = line;
          value = '';
        } else {
          field = line.substring(0, idx);
          value = line.substring(idx + 1).trimLeft();
        }

        if (field == 'event') {
          eventName = value;
        } else if (field == 'data') {
          if (dataBuffer.isNotEmpty) dataBuffer.writeln();
          dataBuffer.write(value);
        }
        // ignore other fields (id, retry)
      }, onDone: () {
        _controller.add({'event': 'sse_disconnect', 'data': {}});
        _scheduleReconnect();
      }, onError: (err) {
        _controller.add({
          'event': 'sse_error',
          'data': {'error': err.toString()}
        });
        _scheduleReconnect();
      }, cancelOnError: true);
    } catch (e) {
      _controller.add({
        'event': 'sse_error',
        'data': {'error': e.toString()}
      });
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectAttempt++;
    final delay = Duration(
        seconds: (_reconnectAttempt > 0 ? (1 << (_reconnectAttempt - 1)) : 1)
            .clamp(1, 30));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_isDisposed) return;
      _startConnection();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _lineSub?.cancel();
    _lineSub = null;
    _client?.close();
    _client = null;
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _controller.close();
  }
}

// Shared instance used across pages
final SseService sseService = SseService();
