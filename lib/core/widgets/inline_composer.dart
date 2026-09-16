import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      ),
                    ),
                    IconButton(
                      tooltip: '取消回复对象',
                      onPressed: busy ? null : onCancelTarget,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              Row(
                key: const ValueKey('composer-input-row'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
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
                      decoration: InputDecoration(
                        hintText: hint,
                        semanticCounterText: '',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => IconButton.filled(
                      tooltip: sendLabel,
                      onPressed:
                          enabled && !busy && value.text.trim().isNotEmpty
                          ? onSend
                          : null,
                      icon: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
