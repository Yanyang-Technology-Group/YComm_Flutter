import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class RealtimeService {
  RealtimeService({
    this.onNotificationChanged,
    this.onSessionInvalid,
    this.pollInterval = const Duration(seconds: 30),
  });
  final Duration pollInterval;
  final void Function()? onNotificationChanged, onSessionInvalid;
  WebSocket? _socket;
  Timer? _retry, _poll;
  int _attempt = 0, _generation = 0;
  bool _closed = true;
  static bool shouldRetry(int code) =>
      [429, 503, 1011, 1013, 1001, 1006].contains(code);
  void connect(Uri uri, {Map<String, String>? headers}) {
    dispose();
    _closed = false;
    final generation = _generation;
    _fallback();
    _open(uri, headers, generation);
  }

  void _fallback() {
    _poll ??= Timer.periodic(
      pollInterval,
      (_) => onNotificationChanged?.call(),
    );
  }

  Future<void> _open(
    Uri uri,
    Map<String, String>? headers,
    int generation,
  ) async {
    try {
      final pending = WebSocket.connect(uri.toString(), headers: headers);
      late WebSocket socket;
      try {
        socket = await pending.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // A timed-out Future does not cancel the underlying handshake.
        unawaited(
          pending.then<void>((lateSocket) async {
            await lateSocket.close();
          }, onError: (Object _) {}),
        );
        rethrow;
      }
      if (_closed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.listen(
        (event) {
          if (_closed || generation != _generation) return;
          try {
            final data = jsonDecode(event as String);
            if (data is Map &&
                ['ready', 'notification.changed'].contains(data['type'])) {
              _attempt = 0;
              _poll?.cancel();
              _poll = null;
              onNotificationChanged?.call();
            }
          } catch (_) {
            /* Ignore unknown server events. */
          }
        },
        onDone: () {
          if (generation != _generation) return;
          final code = socket.closeCode ?? 1006;
          if (code == 1008) {
            dispose();
            onSessionInvalid?.call();
          } else {
            _schedule(uri, headers, generation);
          }
        },
        onError: (Object e) {
          if (generation == _generation) _schedule(uri, headers, generation);
        },
      );
    } catch (e) {
      if (generation != _generation || _closed) return;
      if (e is WebSocketException && [401, 403].contains(e.httpStatusCode)) {
        if (e.httpStatusCode == 401) {
          dispose();
        }
        // An origin/proxy rejection disables socket retries, not REST polling.
        onSessionInvalid?.call();
        return;
      }
      _schedule(uri, headers, generation);
    }
  }

  void _schedule(Uri uri, Map<String, String>? headers, int generation) {
    if (_closed || generation != _generation || _retry?.isActive == true) {
      return;
    }
    _fallback();
    final seconds = min(30, pow(2, min(_attempt++, 5)).toInt());
    _retry = Timer(
      Duration(seconds: seconds, milliseconds: Random().nextInt(400)),
      () => _open(uri, headers, generation),
    );
  }

  void dispose() {
    _closed = true;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _poll?.cancel();
    _poll = null;
    _socket?.close();
    _socket = null;
    _attempt = 0;
  }
}
