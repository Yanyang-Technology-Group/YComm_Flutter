import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// 单项检查结果。
class StatusCheck {
  const StatusCheck({
    required this.name,
    required this.ok,
    required this.elapsedMs,
    this.detail = '',
  });

  final String name;
  final bool ok;
  final int elapsedMs;
  final String detail;
}

/// 一次状态监测的报告。
class StatusReport {
  const StatusReport({
    required this.startedAt,
    required this.totalMs,
    required this.checks,
  });

  final DateTime startedAt;
  final int totalMs;
  final List<StatusCheck> checks;

  bool get passed => checks.every((check) => check.ok);
}

/// 状态监测：跑一组连通性检查，输出一份报告。
///
/// 四项检查：
///   1. 服务器连通性 —— 任意 HTTP 响应都算连通（哪怕 404），记录状态码与延迟；
///   2. API 可用性   —— 调一个真实业务端点，要求 2xx 且返回 JSON；
///   3. WebSocket    —— 握手 `/ws`，成功即通过，记录握手耗时；
///   4. 登录态       —— `/auth/me`，区分「已登录 / 未登录 / 请求失败」。
class StatusMonitor {
  StatusMonitor(this._client);

  final ApiClient _client;

  static const _timeout = Duration(seconds: 8);

  /// 跑一次完整监测。
  Future<StatusReport> run() async {
    final startedAt = DateTime.now();
    final timer = Stopwatch()..start();
    final checks = <StatusCheck>[
      await _serverReachable(),
      await _apiUsable(),
      await _websocketUsable(),
      await _loginState(),
    ];
    timer.stop();
    return StatusReport(
      startedAt: startedAt,
      totalMs: timer.elapsedMilliseconds,
      checks: checks,
    );
  }

  /// 服务器连通性：打 API 根路径，任何 HTTP 响应都算连通。
  ///
  /// 走裸 Dio（不带成功/失败信封解析），保证 4xx/5xx 也能拿到状态码。
  Future<StatusCheck> _serverReachable() async {
    final timer = Stopwatch()..start();
    try {
      final response = await _client.dio.get<dynamic>(
        '/',
        options: Options(
          method: 'GET',
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      timer.stop();
      final code = response.statusCode ?? 0;
      return StatusCheck(
        name: '服务器连通性',
        ok: code > 0,
        elapsedMs: timer.elapsedMilliseconds,
        detail: 'HTTP $code',
      );
    } on DioException catch (error) {
      timer.stop();
      return StatusCheck(
        name: '服务器连通性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: _describe(error),
      );
    } catch (error) {
      timer.stop();
      return StatusCheck(
        name: '服务器连通性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: '$error',
      );
    }
  }

  /// API 可用性：调一个真实业务端点，要求 2xx 且返回 JSON。
  Future<StatusCheck> _apiUsable() async {
    final timer = Stopwatch()..start();
    try {
      final response = await _client.dio.get<dynamic>(
        '/forum/boards',
        options: Options(responseType: ResponseType.plain),
      );
      timer.stop();
      final code = response.statusCode ?? 0;
      final ok = code >= 200 && code < 300;
      final body = response.data is String
          ? response.data as String
          : '${response.data ?? ''}';
      final isJson = body.trimLeft().startsWith('{') ||
          body.trimLeft().startsWith('[');
      return StatusCheck(
        name: 'API 可用性',
        ok: ok && isJson,
        elapsedMs: timer.elapsedMilliseconds,
        detail: ok
            ? (isJson ? 'HTTP $code · 返回 JSON' : 'HTTP $code · 响应不是 JSON')
            : 'HTTP $code',
      );
    } on DioException catch (error) {
      timer.stop();
      return StatusCheck(
        name: 'API 可用性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: _describe(error),
      );
    } catch (error) {
      timer.stop();
      return StatusCheck(
        name: 'API 可用性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: '$error',
      );
    }
  }

  /// WebSocket 可用性：握手 `/ws`，成功即通过，随后主动关闭。
  ///
  /// 与 `RealtimeService` 走同一个地址与头部（cookie + origin）。
  Future<StatusCheck> _websocketUsable() async {
    final timer = Stopwatch()..start();
    WebSocket? socket;
    try {
      final headers = await _client.socketHeaders();
      final base = Uri.parse(_client.dio.options.baseUrl);
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        path: '${base.path}/ws',
      );
      socket = await WebSocket.connect(
        uri.toString(),
        headers: headers,
      ).timeout(_timeout);
      timer.stop();
      return StatusCheck(
        name: 'WebSocket 可用性',
        ok: true,
        elapsedMs: timer.elapsedMilliseconds,
        detail: '握手成功',
      );
    } on TimeoutException {
      timer.stop();
      return StatusCheck(
        name: 'WebSocket 可用性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: '握手超时',
      );
    } on WebSocketException catch (error) {
      timer.stop();
      return StatusCheck(
        name: 'WebSocket 可用性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: error.message,
      );
    } catch (error) {
      timer.stop();
      return StatusCheck(
        name: 'WebSocket 可用性',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: '$error',
      );
    } finally {
      unawaited(socket?.close());
    }
  }

  /// 登录态：`/auth/me` 的三种结果都算「可用」，只把请求失败算作失败。
  Future<StatusCheck> _loginState() async {
    final timer = Stopwatch()..start();
    try {
      final response = await _client.dio.get<dynamic>(
        '/auth/me',
        options: Options(responseType: ResponseType.plain),
      );
      timer.stop();
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        return StatusCheck(
          name: '登录态',
          ok: false,
          elapsedMs: timer.elapsedMilliseconds,
          detail: 'HTTP $code',
        );
      }
      final body = response.data is String
          ? response.data as String
          : '${response.data ?? ''}';
      final loggedIn = body.contains('"user"') &&
          !body.contains('"user":null') &&
          !body.contains('"user": null');
      return StatusCheck(
        name: '登录态',
        ok: true,
        elapsedMs: timer.elapsedMilliseconds,
        detail: loggedIn ? '已登录' : '未登录',
      );
    } on DioException catch (error) {
      timer.stop();
      return StatusCheck(
        name: '登录态',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: _describe(error),
      );
    } catch (error) {
      timer.stop();
      return StatusCheck(
        name: '登录态',
        ok: false,
        elapsedMs: timer.elapsedMilliseconds,
        detail: '$error',
      );
    }
  }

  String _describe(DioException error) {
    final code = error.response?.statusCode;
    if (code != null) return 'HTTP $code';
    return switch (error.type) {
      DioExceptionType.connectionTimeout => '连接超时',
      DioExceptionType.sendTimeout => '发送超时',
      DioExceptionType.receiveTimeout => '接收超时',
      DioExceptionType.connectionError => '网络不可用',
      _ => '${error.message ?? error.type}',
    };
  }
}
