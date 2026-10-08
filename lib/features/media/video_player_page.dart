import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/media/playback.dart';

/// 帖子内视频播放页（整页 / 全屏路由）。
///
/// 手机端就是这一页：左上角返回按钮 + 系统返回键都能退出。
/// 桌面端独立播放窗口与移动端共用这页播放器，窗口进程通过本地 IPC 更新媒体地址。
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.url,
    this.title,
    this.onClose,
    this.softwareSurface = false,
  });
  final String url;
  final String? title;

  /// 独立窗口里用「关闭窗口」，整页路由里用「返回上一页」。
  final VoidCallback? onClose;

  /// 用软件渲染的视频输出面。独立窗口的第二引擎里，硬件加速的
  /// 输出面（Windows 上走 ANGLE 纹理互操作）拿不到帧，表现为「有进度条但画面全黑」，
  /// 软件输出面在两种窗口里都正常。
  final bool softwareSurface;
  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player player;
  late final VideoController controller;
  StreamSubscription<String>? errorSub;
  String? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !widget.softwareSurface,
      ),
    );
    // 出画面之前先别让人对着黑屏猜：把 mpv 的报错原文显示出来。
    errorSub = player.stream.error.listen((message) {
      if (isPlaybackWarning(message)) return;
      if (mounted) setState(() => error = message);
    });
    _open();
  }

  Future<void> _open() async {
    final ticket = ++generation;
    try {
      await openVideo(player, widget.url);
    } catch (failure) {
      if (mounted && ticket == generation) setState(() => error = '$failure');
    }
  }

  @override
  void didUpdateWidget(VideoPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      error = null;
      _open();
    }
  }

  @override
  void dispose() {
    generation++;
    errorSub?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Center(
          child: Video(controller: controller, controls: AdaptiveVideoControls),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed:
                      widget.onClose ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ),
        if (error != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '视频加载失败：$error',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
