part of '../chat_screen.dart';

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;
  final bool enabled;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? (text) => onSend(text) : null,
                  decoration: InputDecoration(
                    hintText: enabled
                        ? 'Ask about players or seasons...'
                        : 'Thinking...',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => IconButton(
                  onPressed: !enabled || value.text.trim().isEmpty
                      ? null
                      : () => onSend(controller.text),
                  icon: Icon(
                    Icons.send_rounded,
                    color: !enabled || value.text.trim().isEmpty
                        ? Colors.grey.shade400
                        : const Color(0xFF00897B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
