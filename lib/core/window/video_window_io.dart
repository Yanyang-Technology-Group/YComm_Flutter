import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/media/video_player_page.dart';

Process? _process;
HttpServer? _server;
Future<bool>? _opening;
Map<String, dynamic> _current = {};
int _revision = 0;

Future<bool> openVideoWindow(String url, String? title) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    return false;
  }
  _current = {'url': url, 'title': title, 'revision': ++_revision};
  if (_process != null) return true;
  return _opening ??= _start().whenComplete(() => _opening = null);
}

Future<bool> _start() async {
  HttpServer? server;
  try {
    final token = base64Url.encode(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      if (request.method != 'GET' ||
          request.uri.path != '/current' ||
          request.headers.value('Authorization') != token) {
        request.response.statusCode = HttpStatus.forbidden;
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_current));
      }
      await request.response.close();
    });
    final process = await Process.start(
      Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable,
      [
        'video-window',
        jsonEncode({..._current, 'port': server.port, 'token': token}),
      ],
    );
    _process = process;
    // Drain child output so a full pipe never stalls playback or shutdown.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    unawaited(
      process.exitCode.then((_) async {
        if (_process == process) {
          _process = null;
          _server = null;
        }
        await server?.close(force: true);
      }),
    );
    return true;
  } catch (_) {
    await server?.close(force: true);
    _server = null;
    return false;
  }
}

Future<void> closeVideoWindow() async {
  // If startup is in flight, wait for it before releasing the child process.
  await _opening;
  final process = _process;
  _process = null;
  await _server?.close(force: true);
  _server = null;
  process?.kill();
  if (process != null) {
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () => -1,
    );
  }
}

Widget videoPlayerWindowApp({
  required int windowId,
  required Map<String, dynamic> argument,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  title: '视频播放',
  home: _VideoWindow(argument: argument),
);

class _VideoWindow extends StatefulWidget {
  const _VideoWindow({required this.argument});
  final Map<String, dynamic> argument;
  @override
  State<_VideoWindow> createState() => _VideoWindowState();
}

class _VideoWindowState extends State<_VideoWindow> {
  late Map<String, dynamic> current;
  Timer? timer;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  bool polling = false;
  int failures = 0;
  @override
  void initState() {
    super.initState();
    current = widget.argument;
    if (current['port'] is int) {
      timer = Timer.periodic(const Duration(milliseconds: 300), (_) => _poll());
    }
  }

  Future<void> _poll() async {
    if (polling) return;
    polling = true;
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${widget.argument['port']}/current'),
      );
      request.headers.set('Authorization', widget.argument['token']);
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw const HttpException('Video owner unavailable');
      }
      final next = jsonDecode(
        await utf8.decoder.bind(response).join(),
      ) as Map<String, dynamic>;
      failures = 0;
      if (mounted && next['revision'] != current['revision']) {
        setState(() => current = next);
        await windowManager.restore();
        await windowManager.show();
        await windowManager.focus();
      }
    } catch (_) {
      if (++failures >= 3) exit(0);
    } finally {
      polling = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    client.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VideoPlayerPage(
    url: current['url'] as String? ?? '',
    title: current['title'] as String?,
    onClose: () => exit(0),
  );
}
