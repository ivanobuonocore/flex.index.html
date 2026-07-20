import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/session_controller.dart';
import '../../document/application/document_controller.dart';
import '../../workspace/application/workspace_controller.dart';
import '../../workspace/presentation/widgets/section_preview.dart';
import '../../workspace/presentation/widgets/workspace_card.dart';
import '../application/chat_controller.dart';
import '../application/message_controller.dart';

/// Home dell'app **e** unica Chat (Fase 3, "Chat unica" — richiesta esplicita
/// dell'utente: "la chat deve essere unica... in un unico posto tutte le
/// attività"). Sostituisce sia la vecchia Home Chat (elenco di conversazioni)
/// sia il dettaglio di una singola Chat: non esiste più una scelta da fare,
/// c'è una sola conversazione (`singleChatProvider`, creata al primo
/// accesso). In testa, la striscia "Sezioni" (Fase 3, slice 7A) resta sempre
/// visibile — non scorre via con i messaggi — così le informazioni che la
/// Chat ha già raccolto (saldo, attività aperte, documenti) sono sempre a un
/// tocco di distanza.
class ChatHomeScreen extends ConsumerWidget {
  const ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).value;
    // Idempotente: crea solo le sezioni fisse mancanti (Fase 3, slice 7A).
    ref.watch(workspaceBootstrapProvider);
    final chatAsync = ref.watch(singleChatProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_greeting(user?.name))),
      body: chatAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile aprire la Chat.',
          onRetry: () => ref.invalidate(singleChatProvider),
        ),
        data: (chat) => _ChatHomeBody(chatId: chat.id),
      ),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final moment = hour < 12
        ? 'Buongiorno'
        : (hour < 18 ? 'Buon pomeriggio' : 'Buonasera');
    return name == null || name.isEmpty ? moment : '$moment, $name';
  }
}

class _ChatHomeBody extends ConsumerWidget {
  const _ChatHomeBody({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(chatId));
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final sections = <Workspace>[
      for (final category in SystemWorkspaceCategory.all)
        ...workspaces.where((w) => w.category == category),
    ];
    // Le transazioni scritte in Chat vanno sempre nella sezione Bilancio, le
    // foto sempre in Documenti — indipendentemente da dove si trovano nella
    // lista (Fase 3, slice 7A ha già reso questi id stabili e unici per
    // categoria). `null` finché il bootstrap non ha ancora creato le sezioni.
    final bilancioId =
        _idForCategory(workspaces, SystemWorkspaceCategory.bilancio);
    final documentiId =
        _idForCategory(workspaces, SystemWorkspaceCategory.documenti);

    return Column(
      children: [
        if (sections.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: AppShadows.card(
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SizedBox(
              height: 128,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: sections.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return SizedBox(
                    width: 240,
                    child: WorkspaceCard(
                      workspace: section,
                      subtitle: SectionPreview(
                        category: section.category!,
                        workspaceId: section.id,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        Expanded(
          child: Container(
            // Colori dello sfondo chat ispirati a WhatsApp (chiaro/scuro):
            // fanno risaltare le bolle molto più di un semplice sfondo
            // bianco/nero.
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFFECE5DD)
                : const Color(0xFF0B141A),
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
                        'Scrivi il primo messaggio per iniziare: puoi raccontare '
                        'una spesa, un appuntamento, o quello che vuoi organizzare.',
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
        ),
        _TypingIndicator(chatId: chatId),
        _MessageInput(
          chatId: chatId,
          transactionsWorkspaceId: bilancioId,
          documentsWorkspaceId: documentiId,
        ),
      ],
    );
  }

  String? _idForCategory(List<Workspace> workspaces, String category) {
    for (final workspace in workspaces) {
      if (workspace.category == category) return workspace.id;
    }
    return null;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor =
        isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    // Angolo "a coda", stile WhatsApp: un raggio molto più piccolo sull'angolo
    // rivolto verso il mittente, gli altri tre restano arrotondati normalmente.
    const tail = Radius.circular(4);
    const round = Radius.circular(AppRadii.standard);
    final bubbleRadius = BorderRadius.only(
      topLeft: round,
      topRight: round,
      bottomLeft: isUser ? round : tail,
      bottomRight: isUser ? tail : round,
    );

    final bubble = Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: bubbleRadius,
        boxShadow: AppShadows.card(isDark: theme.brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final attachmentId in message.attachmentIds) ...[
            _AttachmentImage(documentId: attachmentId),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(message.content,
              style: AppTypography.body.copyWith(color: textColor)),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatTime(message.timestamp),
              style: AppTypography.caption
                  .copyWith(color: textColor.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const _AssistantAvatar(),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: bubble),
        ],
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

/// Piccolo avatar per i messaggi dell'assistente — dà un punto di riferimento
/// visivo a colpo d'occhio (stile app di messaggistica), senza bisogno di
/// un'immagine da caricare: solo un'icona su un cerchio colorato.
class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 14,
      backgroundColor: theme.colorScheme.secondaryContainer,
      child: Icon(Icons.auto_awesome,
          size: 16, color: theme.colorScheme.onSecondaryContainer),
    );
  }
}

/// Foto allegata a un messaggio: la UI conosce solo l'id del [Document]
/// ([Message.attachmentIds]), quindi legge l'oggetto e il suo URL firmato
/// tramite [documentDownloadUrlProvider] prima di poterla mostrare.
class _AttachmentImage extends ConsumerWidget {
  const _AttachmentImage({required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(documentDownloadUrlProvider(documentId));

    return ClipRRect(
      borderRadius: AppRadii.standardRadius,
      child: urlAsync.when(
        loading: () => const SizedBox(
          height: 160,
          width: 160,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const SizedBox(
          height: 80,
          width: 80,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
        data: (url) => Image.network(
          url,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            height: 80,
            width: 80,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends ConsumerWidget {
  const _TypingIndicator({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSending = ref.watch(messageFormControllerProvider).isLoading;
    if (!isSending) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: AppSpacing.sm),
          Text('L\'assistente sta scrivendo…', style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _MessageInput extends ConsumerStatefulWidget {
  const _MessageInput({
    required this.chatId,
    required this.transactionsWorkspaceId,
    required this.documentsWorkspaceId,
  });

  final String chatId;

  /// Sezione Bilancio dell'utente: passata come contesto all'Edge Function
  /// `ai-chat` per abilitare `extract_transactions` (Fase 3, slice 2) — le
  /// transazioni riconosciute in Chat vanno sempre lì.
  final String? transactionsWorkspaceId;

  /// Sezione Documenti dell'utente: dove finisce una foto allegata (diverso
  /// da [transactionsWorkspaceId] — sono due sezioni fisse distinte).
  final String? documentsWorkspaceId;

  @override
  ConsumerState<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<_MessageInput> {
  final _controller = TextEditingController();
  String? _errorMessage;
  PlatformFile? _pendingPhoto;
  bool _isUploadingPhoto = false;
  bool _showEmojiPicker = false;

  bool get _canAttachPhoto => widget.documentsWorkspaceId != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    setState(() => _pendingPhoto = file);
  }

  Future<void> _submit() async {
    final content = _controller.text;
    if (content.trim().isEmpty) return;

    setState(() => _errorMessage = null);

    var attachmentIds = const <String>[];
    final photo = _pendingPhoto;
    if (photo != null) {
      setState(() => _isUploadingPhoto = true);
      final uploadResult =
          await ref.read(documentRepositoryProvider).uploadDocument(
                workspaceId: widget.documentsWorkspaceId!,
                fileName: photo.name,
                mimeType: _guessImageMimeType(photo.extension),
                bytes: photo.bytes!,
                chatId: widget.chatId,
              );
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      if (uploadResult.isErr) {
        setState(() =>
            _errorMessage = (uploadResult as Err<Document>).failure.message);
        return;
      }
      attachmentIds = [(uploadResult as Ok<Document>).value.id];
    }

    _controller.clear();
    setState(() => _pendingPhoto = null);

    final failure = await ref.read(messageFormControllerProvider.notifier).send(
          chatId: widget.chatId,
          workspaceId: widget.transactionsWorkspaceId,
          content: content,
          attachmentIds: attachmentIds,
        );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _errorMessage = failure.message);
    }
  }

  String _guessImageMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  /// Inserisce l'emoji alla posizione del cursore (non solo in coda al
  /// testo) — così funziona anche se l'utente ha già scritto qualcosa e
  /// vuole aggiungere l'emoji in mezzo alla frase.
  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSending =
        ref.watch(messageFormControllerProvider).isLoading || _isUploadingPhoto;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_pendingPhoto != null) ...[
              Chip(
                avatar: const Icon(Icons.image_outlined, size: 18),
                label:
                    Text(_pendingPhoto!.name, overflow: TextOverflow.ellipsis),
                onDeleted: isSending
                    ? null
                    : () => setState(() => _pendingPhoto = null),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_errorMessage != null) ...[
              Text(_errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                IconButton(
                  tooltip: 'Emoji',
                  onPressed: isSending
                      ? null
                      : () =>
                          setState(() => _showEmojiPicker = !_showEmojiPicker),
                  icon: Icon(
                    _showEmojiPicker
                        ? Icons.keyboard_outlined
                        : Icons.emoji_emotions_outlined,
                  ),
                ),
                IconButton(
                  tooltip: _canAttachPhoto
                      ? 'Allega una foto'
                      : 'La sezione Documenti non è ancora pronta',
                  onPressed:
                      (isSending || !_canAttachPhoto) ? null : _pickPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !isSending,
                    decoration:
                        const InputDecoration(hintText: 'Scrivi un messaggio…'),
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
            if (_showEmojiPicker) ...[
              const SizedBox(height: AppSpacing.sm),
              _EmojiPicker(onSelected: _insertEmoji),
            ],
          ],
        ),
      ),
    );
  }
}

/// Selettore di emoji semplice (stile WhatsApp: una tastiera alternativa
/// sotto il campo di testo, non un menu a comparsa). Nessuna dipendenza
/// esterna: sono solo caratteri Unicode, disegnati dal font di sistema —
/// funzionano allo stesso modo su web, Android e iOS senza bisogno di un
/// pacchetto dedicato.
class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _emojis = [
    '😀',
    '😂',
    '🥰',
    '😍',
    '😊',
    '😉',
    '😎',
    '🤔',
    '😅',
    '😭',
    '😢',
    '😡',
    '🥳',
    '😴',
    '🤗',
    '🙄',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '🤝',
    '👋',
    '✌️',
    '❤️',
    '🔥',
    '✨',
    '🎉',
    '👌',
    '💯',
    '⭐',
    '✅',
    '☕',
    '🍕',
    '🎂',
    '🚀',
    '📌',
    '📅',
    '💰',
    '🏠',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: GridView.builder(
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: _emojis.length,
        itemBuilder: (context, index) {
          final emoji = _emojis[index];
          return InkWell(
            borderRadius: AppRadii.buttonRadius,
            onTap: () => onSelected(emoji),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22))),
          );
        },
      ),
    );
  }
}
