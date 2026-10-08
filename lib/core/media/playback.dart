import 'package:media_kit/media_kit.dart';

import 'playback_platform.dart'
    if (dart.library.io) 'playback_platform_io.dart';
import 'video_urls.dart';

const videoHttpHeaders = {
  'User-Agent': 'Mozilla/5.0 YCommFlutter',
  'Accept': '*/*',
  'Accept-Encoding': 'identity',
  'Referer': 'https://community.yanyn.cn/',
};

bool isPlaybackWarning(String message) =>
    message.contains('--force-seekable') ||
    message.contains('Cannot seek in this stream') ||
    message.contains('Stream is not seekable');

Future<void> openVideo(
  Player player,
  String url, {
  bool play = true,
  bool original = false,
}) async {
  await configureNativePlayback(player);
  await player.open(
    Media(
      original ? url : videoPlaybackUrl(url),
      httpHeaders: videoHttpHeaders,
    ),
    play: play,
  );
}
