import '../design/adaptive.dart';

import 'package:flutter/material.dart';

import '../design/apple_chrome.dart';
import '../design/tokens.dart';

class InlineComposer extends StatelessWidget {
  const InlineComposer({
    super.key,
    required this.controller,
    required this.inputKey,
    required this.hint,
    required this.onSend,
    this.focusNode,
    this.busy = false,
    this.enabled = true,
    this.target,
    this.onCancelTarget,
    this.sendLabel = '发送',
  });
  final TextEditingController controller;
  final Key inputKey;
  final String hint, sendLabel;
  final VoidCallback onSend;
  final FocusNode? focusNode;
  final bool busy, enabled;
  final String? target;
  final VoidCallback? onCancelTarget;

  @override
  Widget build(BuildContext context) {
    final apple = appleTokensOf(context) != null;
    final scheme = Theme.of(context).colorScheme;
    // Apple 风格：输入条是一层半透明材质，讨论正文从它下面滚过去（技能第 12 条）；
    // 输入框是胶囊形填充，发送键是圆形箭头——形状本身说明「往上送」。
    final surface = apple
        ? TranslucentBar(
            blur: 24,
            edge: TranslucentEdge.top,
            child: SafeArea(top: false, child: _body(context, apple)),
          )
        : AppSurface(
            color: scheme.surface,
            child: SafeArea(top: false, child: _body(context, apple)),
          );
    return surface;
  }

  Widget _body(BuildContext context, bool apple) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      heightFactor: 1,
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(maxWidth: apple ? 680 : 720),
        padding: EdgeInsets.symmetric(
          horizontal: apple ? AppleSpacing.md : 16,
          vertical: apple ? 8 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (target != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 $target',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: apple
                          ? AppleType.footnote.copyWith(
                              color: scheme.primary,
                              fontFamilyFallback: appleFontFallback,
                            )
                          : null,
                    ),
                  ),
                  AppIconButton(
                    tooltip: '取消回复对象',
                    onPressed: busy ? null : onCancelTarget,
                    icon: const AppIcon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            Row(
              key: const ValueKey('composer-input-row'),
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AppTextField(
                    key: inputKey,
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled && !busy,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 100000,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: apple
                        ? AppleType.body.copyWith(
                            color: scheme.onSurface,
                            fontFamilyFallback: appleFontFallback,
                          )
                        : null,
                    decoration: InputDecoration(
                      hintText: hint,
                      semanticCounterText: '',
                      counterText: '',
                      // Apple 侧用胶囊：圆角取一个必然超过半高的值，
                      // 这样单行和多行都不会出现「圆角被撑破」的观感。
                      border: apple
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            )
                          : null,
                      enabledBorder: apple
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            )
                          : null,
                      focusedBorder: apple
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            )
                          : null,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: apple ? 14 : 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => AppIconButton.filled(
                    tooltip: sendLabel,
                    onPressed: enabled && !busy && value.text.trim().isNotEmpty
                        ? onSend
                        : null,
                    icon: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: AppSpinner(strokeWidth: 2),
                          )
                        : const AppIcon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
