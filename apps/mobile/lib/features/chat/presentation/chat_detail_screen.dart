import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/message_controller.dart';

/// Dettaglio di una Chat: storico messaggi (realtime) + campo di invio
/// (docs/product/06-information-architecture.md, "Chat").
/// [workspaceId] è passato all'Edge Function per costruire il contesto
/// (`null` per una Chat privata, non collegata a nessun Workspace).
class ChatDetailScreen extends ConsumerWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.workspaceId,
  });

  final String chatId;
  final String? workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(chatId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingView(),
              error: (error, stackTrace) => ErrorView(
                message: 'Non è stato possibile caricare i messaggi.',
                onRetry: () => ref.invalidate(messagesProvider(chatId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Scrivi il primo messaggio per iniziare la conversazione.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                );
              },
            ),
          ),
          _TypingIndicator(chatId: chatId),
          _MessageInput(chatId: chatId, workspaceId: workspaceId),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final bubbleColor =
        isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: AppRadii.standardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.content, style: AppTypography.body.copyWith(color: textColor)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _formatTime(message.timestamp),
              style: AppTypography.caption.copyWith(color: textColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TypingIndicator extends ConsumerWidget {
  const _TypingIndicator({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSending = ref.watch(messageFormControllerProvider).isLoading;
    if (!isSending) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.sm),
          Text('L\'assistente sta scrivendo…', style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _MessageInput extends ConsumerStatefulWidget {
  const _MessageInput({required this.chatId, required this.workspaceId});

  final String chatId;
  final String? workspaceId;

  @override
  ConsumerState<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<_MessageInput> {
  final _controller = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text;
    if (content.trim().isEmpty) return;

    setState(() => _errorMessage = null);
    _controller.clear();

    final failure = await ref.read(messageFormControllerProvider.notifier).send(
          chatId: widget.chatId,
          workspaceId: widget.workspaceId,
          content: content,
        );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _errorMessage = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(messageFormControllerProvider).isLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !isSending,
                    decoration: const InputDecoration(hintText: 'Scrivi un messaggio…'),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: isSending ? null : _submit,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
