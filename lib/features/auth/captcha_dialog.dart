import '../../core/design/adaptive.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'captcha_session.dart';
import 'captcha_webview.dart';

Future<String?> showCaptchaDialog(BuildContext context) {
  FocusScope.of(context).unfocus();
  return appShowDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const CaptchaDialog(),
  );
}

typedef CaptchaSessionFactory = Future<CaptchaChallenge> Function(bool dark);
typedef CaptchaViewBuilder = Widget Function(Uri uri, VoidCallback onError);

class CaptchaDialog extends StatefulWidget {
  const CaptchaDialog({super.key, this.sessionFactory, this.viewBuilder});
  // Injection points allow testing the entire lifecycle without a native view.
  final CaptchaSessionFactory? sessionFactory;
  final CaptchaViewBuilder? viewBuilder;
  @override
  State<CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<CaptchaDialog> {
  CaptchaChallenge? _session;
  String? _error;
  int _generation = 0;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final previous = _session;
    setState(() {
      _session = null;
      _error = null;
      _starting = true;
    });
    await previous?.close();
    if (!mounted || generation != _generation) return;
    CaptchaChallenge? current;
    try {
      final dark = Theme.of(context).brightness == Brightness.dark;
      current =
          await (widget.sessionFactory?.call(dark) ??
              CaptchaSession.start(dark: dark));
      if (!mounted || generation != _generation) {
        await current.close();
        return;
      }
      setState(() {
        _session = current;
        _starting = false;
      });
      final token = await current.token;
      if (!mounted || generation != _generation) return;
      if (token == null) {
        _fail(generation, '验证已超时，请重新验证');
      } else {
        ++_generation;
        Navigator.of(context).pop(token);
      }
    } catch (_) {
      _fail(generation, '无法加载验证组件，请检查网络后重试');
    } finally {
      await current?.close();
    }
  }

  void _fail(int generation, String message) {
    if (!mounted || generation != _generation) return;
    ++_generation; // Ignore completion callbacks from the abandoned WebView.
    final old = _session;
    setState(() {
      _session = null;
      _starting = false;
      _error = message;
    });
    unawaited(old?.close());
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final scheme = Theme.of(context).colorScheme;
    return AppDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(Icons.verified_user_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '完成人机验证',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '点击下方组件完成验证，成功后会自动继续。',
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.6),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _error != null
                    ? Center(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.error, height: 1.6),
                          ),
                        ),
                      )
                    : _session == null
                    ? const Center(child: AppSpinner())
                    : KeyedSubtree(
                        key: ValueKey(_session!.uri),
                        child:
                            widget.viewBuilder?.call(
                              _session!.uri,
                              () => _fail(generation, '验证页面加载失败，请检查网络后重试'),
                            ) ??
                            CaptchaWebView(
                              uri: _session!.uri,
                              onError: () =>
                                  _fail(generation, '验证页面加载失败，请检查网络后重试'),
                            ),
                      ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  AppTextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  AppTextButton.icon(
                    onPressed: _starting ? null : _start,
                    icon: const AppIcon(Icons.refresh_rounded, size: 18),
                    label: const Text('重新验证'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
