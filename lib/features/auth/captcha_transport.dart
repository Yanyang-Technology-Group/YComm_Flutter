import 'dart:async';
import 'dart:io';

/// A restricted transport for the official CAP widget. Never shares login
/// cookies, follows redirects, disables TLS checks, or solves challenges.
class CaptchaTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  Future<CaptchaResource> load(Uri uri, String method, List<int> body) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    if (method == 'POST') {
      request.headers.contentType = ContentType.json;
      request.add(body);
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('CAP response too large');
      }
    }
    if (response.isRedirect) throw const HttpException('CAP redirect refused');
    return CaptchaResource(response.statusCode, bytes);
  }

  void close() => _client.close(force: true);
}

class CaptchaResource {
  const CaptchaResource(this.statusCode, this.bytes);
  final int statusCode;
  final List<int> bytes;
}

typedef CaptchaResourceLoader = Future<CaptchaResource> Function(
  Uri uri,
  String method,
  List<int> body,
);
