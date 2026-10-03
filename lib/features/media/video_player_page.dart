import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 帖子内视频播放页（整页 / 全屏路由）。
///
/// 手机端就是这一页：左上角返回按钮 + 系统返回键都能退出。
/// 桌面端先用同一页，独立播放窗口（desktop_multi_window）是下一步单独提交，
/// 它需要各平台原生改动，和播放器本身分开验证更稳。
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.url,
    this.title,
    this.onClose,
  });
  final String url;
  final String? title;
  /// 独立窗口里用「关闭窗口」，整页路由里用「返回上一页」。
  final VoidCallback? onClose;
  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    // 打开即播放；失败不弹错误页，播放器自己会显示加载/错误状态。
    player.open(Media(widget.url));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Center(
          child: Video(
            controller: controller,
            controls: AdaptiveVideoControls,
          ),
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
      ],
    ),
  );
}
