import '../../core/design/adaptive.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

/// Only the ephemeral local challenge document may occupy this WebView.
/// CAP resources use the fixed, session-scoped transport; navigation cannot
/// launch another site or application.
bool isCaptchaNavigationAllowed(Uri challenge, String destination) =>
    Uri.tryParse(destination) == challenge;

class CaptchaWebView extends StatefulWidget {
  const CaptchaWebView({super.key, required this.uri, required this.onError});
  final Uri uri;
  final VoidCallback onError;
  @override
  State<CaptchaWebView> createState() => _CaptchaWebViewState();
}

class _CaptchaWebViewState extends State<CaptchaWebView> {
  WebViewController? _controller;
  late final Future<void> _initialization;
  Timer? _loadTimeout;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeout = Timer(const Duration(seconds: 25), _fail);
    _initialization = _initialize();
  }

  void _fail() {
    _loadTimeout?.cancel();
    // Native initialization can fail synchronously while the parent is building.
    scheduleMicrotask(() {
      if (mounted) widget.onError();
    });
  }

  Future<void> _initialize() async {
    try {
      final controller = WebViewController(
        onPermissionRequest: (request) => request.deny(),
      );
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              isCaptchaNavigationAllowed(widget.uri, request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) {
            _loadTimeout?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _fail();
          },
          onSslAuthError: (error) {
            error.cancel();
            _fail();
          },
        ),
      );
      if (!mounted) return;
      await controller.loadRequest(widget.uri);
      if (mounted) setState(() {});
    } catch (_) {
      _fail();
    }
  }

  Future<void> _release() async {
    await _initialization;
    final controller = _controller;
    if (controller == null) return;
    try {
      // Destroy the challenge document and its workers even when the platform
      // keeps its controller alive until finalization.
      await controller.runJavaScript('window.stop();');
      await controller.setNavigationDelegate(NavigationDelegate());
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.loadHtmlString('<!doctype html><html></html>');
    } catch (_) {
      // Native platform views may already have been disposed by the framework.
    }
    try {
      if (await controller.isOffscreenWebViewSupported()) {
        // The native close hook destroys owned controllers on all platforms,
        // including when a previously visible view has just been removed.
        await controller.platform.closeOffscreenWebView();
      }
    } catch (_) {
      // Some platforms dispose their view together with its widget.
    }
    _controller = null;
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (_loading) const AppProgress(minHeight: 2),
      Expanded(
        child: _controller == null
            ? const Center(child: Text('正在准备验证组件…'))
            : WebViewWidget(controller: _controller!),
      ),
    ],
  );
}
