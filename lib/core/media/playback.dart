import 'package:media_kit/media_kit.dart';

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

Future<void> openVideo(Player player, String url, {bool play = true}) async {
  final native = player.platform;
  if (native is NativePlayer) {
    await native.setProperty('force-seekable', 'yes');
    await native.setProperty('network-timeout', '20');
    await native.setProperty('demuxer-readahead-secs', '8');
  }
  await player.open(Media(url, httpHeaders: videoHttpHeaders), play: play);
}
