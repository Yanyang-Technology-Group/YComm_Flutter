import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/media/playback.dart';

void main() {
  test('seekability warnings do not hide real network or decoder failures', () {
    expect(
      isPlaybackWarning("You can force it with '--force-seekable=yes'"),
      isTrue,
    );
    expect(isPlaybackWarning('Stream is not seekable'), isTrue);
    expect(isPlaybackWarning('HTTP error 404 Not Found'), isFalse);
    expect(
      isPlaybackWarning('Failed to open https://example.test/video.mp4'),
      isFalse,
    );
    expect(isPlaybackWarning('Cannot initialize video decoder'), isFalse);
  });
}
