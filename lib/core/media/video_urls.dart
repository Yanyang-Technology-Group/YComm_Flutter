Uri? uploadedVideoUri(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.host != 'community.yanyn.cn' ||
      !RegExp(
        r'^/api/uploads/videos/[A-Za-z0-9_-]{8,64}\.(mp4|webm|mov)$',
        caseSensitive: false,
      ).hasMatch(uri.path)) {
    return null;
  }
  return uri;
}

String videoPlaybackUrl(String url) {
  final uri = uploadedVideoUri(url);
  return uri == null
      ? url
      : Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: '${uri.path}/playback',
        ).toString();
}

String? videoPosterUrl(String url) {
  final uri = uploadedVideoUri(url);
  return uri == null
      ? null
      : Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
          path: '${uri.path}/poster',
        ).toString();
}
