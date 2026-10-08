import 'package:media_kit/media_kit.dart';

Future<void> configureNativePlayback(Player player) async {
  final native = player.platform;
  if (native is NativePlayer) {
    await native.setProperty('force-seekable', 'yes');
    await native.setProperty('network-timeout', '20');
    await native.setProperty('demuxer-readahead-secs', '8');
  }
}
