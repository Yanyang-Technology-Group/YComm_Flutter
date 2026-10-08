import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/media/video_urls.dart';

void main() {
  test('uploaded videos use fast-start streams and cached server posters', () {
    const url =
        'https://community.yanyn.cn/api/uploads/videos/68ca246f-8038-4f59-9b1f-4e27cf4921ab.mp4';
    expect(videoPlaybackUrl('$url?old=1'), '$url/playback');
    expect(videoPosterUrl(url), '$url/poster');
  });
  test('external and non-video URLs preserve their transport', () {
    for (final url in [
      'https://cdn.example/video.mp4?token=abc',
      'https://community.yanyn.cn/api/uploads/images/image123.jpg',
    ]) {
      expect(videoPlaybackUrl(url), url);
      expect(videoPosterUrl(url), isNull);
    }
  });
}
