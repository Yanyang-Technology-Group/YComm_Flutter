import '../../core/design/adaptive.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import 'github_auth.dart';

class GithubLoginPage extends StatefulWidget {
  const GithubLoginPage({super.key});
  @override
  State<GithubLoginPage> createState() => _GithubLoginPageState();
}

class _GithubLoginPageState extends State<GithubLoginPage> {
  GithubAuth? _auth;
  WebViewController? _controller;
  Timer? _timeout, _loadTimeout;
  int _generation = 0;
  bool _loading = true, _exchanging = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _release(WebViewController? controller) async {
    if (controller == null) return;
    try {
      // No scripts are injected into GitHub pages and no GitHub cookies read.
      await controller.setNavigationDelegate(NavigationDelegate());
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.loadHtmlString('<!doctype html><html></html>');
      if (await controller.isOffscreenWebViewSupported()) {
        await controller.platform.closeOffscreenWebView();
      }
    } catch (_) {
      // A native platform view may already be disposed with its widget.
    }
  }

  void _fail(int generation, String message) {
    if (!mounted || generation != _generation) return;
    ++_generation;
    _timeout?.cancel();
    _loadTimeout?.cancel();
    _auth?.close();
    final old = _controller;
    setState(() {
      _controller = null;
      _error = message;
      _loading = false;
      _exchanging = false;
    });
    unawaited(_release(old));
  }

  void _watchLoad(int generation) {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(
      const Duration(seconds: 45),
      () => _fail(generation, 'GitHub 页面连接超时，请检查网络或代理后重试'),
    );
  }

  Future<void> _start() async {
    final generation = ++_generation;
    _watchLoad(generation);
    _auth?.close();
    final old = _controller;
    setState(() {
      _controller = null;
      _error = null;
      _loading = true;
      _exchanging = false;
    });
    await _release(old);
    if (!mounted || generation != _generation) return;
    final auth = GithubAuth();
    _auth = auth;
    _timeout?.cancel();
    _loadTimeout?.cancel();
    _watchLoad(generation);
    _timeout = Timer(
      const Duration(minutes: 30),
      () => _fail(generation, 'GitHub 授权已超时，请重新登录'),
    );
    WebViewController? controller;
    try {
      final authorize = await auth.start();
      if (!mounted || generation != _generation) return;
      controller = WebViewController(
        onPermissionRequest: (request) => request.deny(),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!mounted || generation != _generation || _exchanging) {
              return NavigationDecision.prevent;
            }
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (auth.isCallback(uri)) {
              if (request.isMainFrame) {
                unawaited(_finish(generation, auth, uri));
              }
              return NavigationDecision.prevent;
            }
            return GithubAuth.isGithubPage(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (generation == _generation) _watchLoad(generation);
            if (mounted && generation == _generation) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) {
            if (generation == _generation) _loadTimeout?.cancel();
            if (mounted && generation == _generation) {
              setState(() => _loading = false);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && !_exchanging) {
              _fail(generation, 'GitHub 页面加载失败，请检查网络或系统代理后重试');
            }
          },
          onSslAuthError: (error) {
            error.cancel();
            _fail(generation, '无法安全连接 GitHub，请检查设备时间与网络');
          },
        ),
      );
      if (!mounted || generation != _generation) {
        await _release(controller);
        return;
      }
      _controller = controller;
      await controller.loadRequest(authorize);
      if (mounted && generation == _generation) setState(() {});
    } catch (error) {
      if (_controller != controller) await _release(controller);
      _fail(
        generation,
        error is GithubAuthException ? error.message : '无法打开 GitHub 授权，请稍后重试',
      );
    }
  }

  Future<void> _finish(int generation, GithubAuth auth, Uri callback) async {
    if (_exchanging) return;
    _loadTimeout?.cancel();
    setState(() => _exchanging = true);
    try {
      final cookies = await auth.finish(callback);
      if (!mounted || generation != _generation) return;
      ++_generation;
      Navigator.of(context).pop<List<Cookie>>(cookies);
    } catch (error) {
      _fail(
        generation,
        error is GithubAuthException ? error.message : 'GitHub 登录失败，请重新尝试',
      );
    }
  }

  @override
  void dispose() {
    ++_generation;
    _timeout?.cancel();
    _loadTimeout?.cancel();
    _auth?.close();
    unawaited(_release(_controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppNavigationBar(
      title: const Text('GitHub 登录'),
      actions: [
        AppIconButton(
          tooltip: '重新授权',
          onPressed: _exchanging ? null : _start,
          icon: const AppIcon(Icons.refresh_rounded),
        ),
      ],
      leading: AppIconButton(
        tooltip: '取消登录',
        icon: const AppIcon(Icons.close_rounded),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                AppIcon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'github.com · 官方授权',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (_loading || _exchanging) const AppProgress(minHeight: 2),
          Expanded(
            child: _error != null
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AppIcon(Icons.cloud_off_rounded, size: 40),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          AppFilledButton.icon(
                            onPressed: _start,
                            icon: const AppIcon(Icons.refresh_rounded),
                            label: const Text('重新授权'),
                          ),
                          AppTextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('返回登录'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _exchanging
                ? const Center(child: Text('正在确认社区登录状态…'))
                : _controller == null
                ? const Center(child: Text('正在连接 GitHub…'))
                : WebViewWidget(controller: _controller!),
          ),
        ],
      ),
    ),
  );
}
