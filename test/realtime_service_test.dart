import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/realtime_service.dart';

void main() {
  test('only retryable websocket closures reconnect', () {
    expect(RealtimeService.shouldRetry(503), isTrue);
    expect(RealtimeService.shouldRetry(1013), isTrue);
    expect(RealtimeService.shouldRetry(401), isFalse);
    expect(RealtimeService.shouldRetry(1008), isFalse);
  });
  test(
    'ready and change events refresh REST; session invalid stops reconnect',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      WebSocket? connection;
      int refreshes = 0, requests = 0;
      final invalid = Completer<void>();
      final service = RealtimeService(
        onNotificationChanged: () => refreshes++,
        onSessionInvalid: () => invalid.complete(),
      );
      addTearDown(() async {
        service.dispose();
        await connection?.close();
        await server.close(force: true);
      });
      final connected = Completer<void>();
      server.listen((r) async {
        requests++;
        expect(r.headers.value('origin'), 'http://127.0.0.1');
        expect(r.headers.value('cookie'), 'session=test');
        connection = await WebSocketTransformer.upgrade(r);
        connection!.add('{"type":"ready"}');
        connection!.add('{"type":"notification.changed"}');
        connected.complete();
      });
      service.connect(
        Uri.parse('ws://127.0.0.1:${server.port}/api/ws'),
        headers: {'Origin': 'http://127.0.0.1', 'Cookie': 'session=test'},
      );
      await connected.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(refreshes, 2);
      await connection!.close(1008, 'session_invalid');
      await invalid.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests, 1);
    },
  );
  test('socket rejection keeps REST fallback; dispose stops polling', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    int refreshes = 0, requests = 0;
    final service = RealtimeService(
      pollInterval: const Duration(milliseconds: 25),
      onNotificationChanged: () => refreshes++,
    );
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });
    server.listen((r) async {
      requests++;
      r.response.statusCode = 403;
      await r.response.close();
    });
    service.connect(Uri.parse('ws://127.0.0.1:${server.port}/api/ws'));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(refreshes, greaterThanOrEqualTo(2));
    expect(requests, 1);
    service.dispose();
    final before = refreshes;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(refreshes, before);
  });
  test('server restart closure reconnects and resumes notifications', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    int requests = 0;
    final reconnected = Completer<void>();
    final service = RealtimeService();
    addTearDown(() async {
      service.dispose();
      for (final s in sockets) {
        await s.close();
      }
      await server.close(force: true);
    });
    server.listen((r) async {
      requests++;
      final s = await WebSocketTransformer.upgrade(r);
      sockets.add(s);
      s.add('{"type":"ready"}');
      if (requests == 1) {
        await s.close(1001, 'server_shutdown');
      } else if (!reconnected.isCompleted) {
        reconnected.complete();
      }
    });
    service.connect(Uri.parse('ws://127.0.0.1:${server.port}/api/ws'));
    await reconnected.future.timeout(const Duration(seconds: 4));
    expect(requests, 2);
  });
}
