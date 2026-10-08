import 'dart:async';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playback.dart';

final _posters = <String, Future<Uint8List?>>{};
Future<void> _queue = Future.value();

/// Decode one preview at a time; reuse the result when returning to a topic.
Future<Uint8List?> videoPoster(String url) {
  final cached = _posters[url];
  if (cached != null) return cached;
  if (_posters.length >= 24) _posters.remove(_posters.keys.first);
  final result = _queue.then((_) => _decode(url));
  _queue = result.then<void>(
    (_) {},
    onError: (Object error, StackTrace stack) {},
  );
  _posters[url] = result;
  return result;
}

Future<Uint8List?> _decode(String url) async {
  Player? player;
  try {
    player = Player(
      configuration: const PlayerConfiguration(bufferSize: 4 * 1024 * 1024),
    );
    final controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        width: 384,
        height: 216,
        enableHardwareAcceleration: false,
      ),
    );
    await player.setVolume(0);
    await openVideo(player, url).timeout(const Duration(seconds: 12));
    await controller.waitUntilFirstFrameRendered.timeout(
      const Duration(seconds: 12),
    );
    await player.pause();
    return await player.screenshot();
  } catch (_) {
    return null;
  } finally {
    try {
      await player?.dispose();
    } catch (_) {
      // A decoder cleanup failure must not block subsequent previews.
    }
  }
}
