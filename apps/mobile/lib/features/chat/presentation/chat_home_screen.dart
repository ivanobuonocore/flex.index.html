import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/session_controller.dart';
import '../../document/application/document_controller.dart';
import '../../workspace/application/workspace_category_meta.dart';
import '../../workspace/application/workspace_controller.dart';
import '../../workspace/presentation/widgets/section_preview.dart';
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
class ChatHomeScreen extends ConsumerStatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  ConsumerState<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

/// Un trigger Postgres (`messages_touch_chat_last_message`) aggiorna
/// `chats.last_message_at` ad ogni messaggio inserito — sia quello
/// dell'utente sia quello dell'assistente. `singleChatProvider` dipende da
/// `chatsProvider(null)` (uno stream realtime sulla tabella `chats`), quindi
/// quell'aggiornamento lo fa "ricaricare" ad ogni invio e ad ogni risposta.
/// Per le regole di default di Riverpod un ricaricamento del genere (diverso
/// da un refresh manuale) passa comunque dal ramo `loading:` di
/// `AsyncValue.when()`: senza questa cache, ad ogni messaggio l'intero corpo
/// della schermata veniva sostituito con `LoadingView()`, distruggendo e
/// ricreando da zero `_ChatHomeBody`/`_MessagesArea` — con essi lo
/// `ScrollController` e la cache dei messaggi già mostrati. Era questa,
/// non lo stream dei messaggi, la vera causa dello scatto "sale e poi
/// scende" e del lampo su una parte più vecchia della conversazione (la
/// lista ricreata riparte dalla cima, offset zero, prima del salto
/// automatico in fondo).
class _ChatHomeScreenState extends ConsumerState<ChatHomeScreen> {
  String? _lastKnownChatId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).value;
    // Idempotente: crea solo le sezioni fisse mancanti (Fase 3, slice 7A).
    ref.watch(workspaceBootstrapProvider);
    final chatAsync = ref.watch(singleChatProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_greeting(user?.name))),
      body: chatAsync.when(
        loading: () {
          final cachedId = _lastKnownChatId;
          if (cachedId != null) return _ChatHomeBody(chatId: cachedId);
          return const LoadingView();
        },
        error: (error, stackTrace) {
          final cachedId = _lastKnownChatId;
          if (cachedId != null) return _ChatHomeBody(chatId: cachedId);
          return ErrorView(
            message: 'Non è stato possibile aprire la Chat.',
            onRetry: () => ref.invalidate(singleChatProvider),
          );
        },
        data: (chat) {
          _lastKnownChatId = chat.id;
          return _ChatHomeBody(chatId: chat.id);
        },
      ),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final moment = hour < 12
        ? 'Buongiorno'
        : (hour < 18 ? 'Buon pomeriggio' : 'Buonasera');
    return name == null || name.isEmpty
        ? moment
        : '$moment, ${_capitalize(name)}';
  }

  String _capitalize(String name) => name[0].toUpperCase() + name.substring(1);
}

class _ChatHomeBody extends ConsumerWidget {
  const _ChatHomeBody({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            // Più sottile e leggera della card completa usata nella tab
            // Workspace (richiesta esplicita dell'utente: "più sottile ed
            // esteticamente più bella ed intuitiva") — solo icona, nome e
            // anteprima, senza il menu Rinomina/Elimina: qui è una scorciatoia
            // di lettura, non il posto da cui gestire un Workspace.
            child: SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sections.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _SectionChip(workspace: section);
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
            child: _MessagesArea(chatId: chatId),
          ),
        ),
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

/// Sezione fissa nella striscia in testa alla Chat: solo icona colorata,
/// nome e anteprima viva — nessun menu (quello resta nella tab Workspace).
class _SectionChip extends StatelessWidget {
  const _SectionChip({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    final meta = WorkspaceCategoryMeta.of(workspace.category);
    final tint = meta?.color ?? Theme.of(context).colorScheme.primary;
    final icon = meta?.icon ?? Icons.folder_outlined;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: AppRadii.buttonRadius,
      child: InkWell(
        borderRadius: AppRadii.buttonRadius,
        onTap: () => GoRouter.of(context).push('/workspace/${workspace.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: tint.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: tint),
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      workspace.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    SectionPreview(
                      category: workspace.category!,
                      workspaceId: workspace.id,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Messaggi con scorrimento automatico verso il basso — senza, ogni nuovo
/// messaggio (proprio o dell'assistente) restava fuori vista finché l'utente
/// non scorreva a mano: bug segnalato dall'utente ("quando risponde non si
/// blocca la pagina ma che esca di seguito senza scatti, come una normale
/// conversazione su whatsapp"). L'indicatore "sta scrivendo" è ora l'ultimo
/// elemento della stessa lista (non un widget fisso sotto, che cambiando
/// altezza disponibile della lista causava lo "scatto" percepito) — appare e
/// scompare nel normale flusso di scroll, come la bolla "..." di WhatsApp.
class _MessagesArea extends ConsumerStatefulWidget {
  const _MessagesArea({required this.chatId});

  final String chatId;

  @override
  ConsumerState<_MessagesArea> createState() => _MessagesAreaState();
}

class _MessagesAreaState extends ConsumerState<_MessagesArea> {
  final _scrollController = ScrollController();
  bool _scrolledInitially = false;

  // Non deriva più direttamente da `messageFormControllerProvider.isLoading`:
  // misurando lo scroll frame per frame (vedi scroll_diagnostic_test.dart) si
  // vede che la risposta HTTP di sendMessage (che fa scattare isLoading a
  // false) arriva tipicamente PRIMA della notifica Realtime dell'insert del
  // messaggio dell'assistente (due canali indipendenti, con latenze
  // indipendenti). Nascondere la bolla "sta scrivendo" a isLoading=false
  // toglieva contenuto dalla lista mentre lo scroll era ancorato in fondo:
  // Flutter corregge la posizione istantaneamente, senza animazione — lo
  // scatto "sale e poi scende" segnalato dall'utente. Resta visibile finché
  // non arriva davvero l'ultimo messaggio dell'assistente, con un timeout di
  // sicurezza in caso di errore (nessun messaggio in arrivo).
  bool _waitingForReply = false;
  Timer? _waitingForReplyTimeout;

  // Il flusso realtime di `messagesProvider` può ripartire da zero (es. una
  // riconnessione del canale Supabase Realtime) e ripassare per uno stato di
  // caricamento: osservato in produzione subito dopo un invio, con la lista
  // che spariva per un istante mostrando una schermata vuota — o perfino una
  // porzione molto più vecchia della conversazione, prima di riallinearsi —
  // un secondo scatto indipendente da quelli già corretti sopra. Tenendo in
  // cache l'ultimo elenco valido e continuando a mostrarlo durante un
  // ricaricamento (invece di sostituirlo con uno spinner a schermo intero),
  // quel ricaricamento diventa invisibile: la lista non sparisce mai.
  List<Message>? _lastKnownMessages;

  @override
  void dispose() {
    _scrollController.dispose();
    _waitingForReplyTimeout?.cancel();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messagesProvider(widget.chatId), (_, next) {
      final optimisticNotifier =
          ref.read(optimisticMessageProvider(widget.chatId).notifier);
      if (optimisticNotifier.state != null) optimisticNotifier.state = null;
      final messages = next.value;
      if (_waitingForReply &&
          messages != null &&
          messages.isNotEmpty &&
          messages.last.role == MessageRole.ai) {
        _waitingForReplyTimeout?.cancel();
        setState(() => _waitingForReply = false);
      }
      _scrollToBottom();
    });
    ref.listen(
      messageFormControllerProvider.select((state) => state.isLoading),
      (previous, isLoading) {
        if (isLoading) {
          // Annulla un eventuale timeout di sicurezza rimasto da un
          // isLoading->false precedente e NON collegato a questo invio (es.
          // quello innocuo generato dalla stessa inizializzazione del
          // provider all'apertura della chat, coperto anche da un test
          // dedicato): senza questa cancellazione, quel timer può scattare
          // a metà di un invio successivo e nascondere la bolla troppo
          // presto — bug osservato riproducendo la sequenza in un browser
          // reale con log di diagnostica.
          _waitingForReplyTimeout?.cancel();
          setState(() => _waitingForReply = true);
          _scrollToBottom();
          return;
        }
        // Non nasconde subito la bolla: aspetta il messaggio reale (vedi
        // sopra) o, se non arriva mai (es. errore), il timeout di sicurezza.
        _waitingForReplyTimeout?.cancel();
        _waitingForReplyTimeout = Timer(const Duration(seconds: 5), () {
          if (mounted && _waitingForReply) {
            setState(() => _waitingForReply = false);
          }
        });
      },
    );
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final optimisticMessage =
        ref.watch(optimisticMessageProvider(widget.chatId));

    return messagesAsync.when(
      loading: () {
        final cached = _lastKnownMessages;
        if (cached != null) return _buildList(cached, optimisticMessage);
        return const LoadingView();
      },
      error: (error, stackTrace) {
        final cached = _lastKnownMessages;
        if (cached != null) return _buildList(cached, optimisticMessage);
        return ErrorView(
          message: 'Non è stato possibile caricare i messaggi.',
          onRetry: () => ref.invalidate(messagesProvider(widget.chatId)),
        );
      },
      data: (messages) {
        _lastKnownMessages = messages;
        return _buildList(messages, optimisticMessage);
      },
    );
  }

  Widget _buildList(List<Message> messages, Message? optimisticMessage) {
    final displayMessages = [
      ...messages,
      if (optimisticMessage != null) optimisticMessage,
    ];
    if (displayMessages.isEmpty && !_waitingForReply) {
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
    if (!_scrolledInitially && messages.isNotEmpty) {
      _scrolledInitially = true;
      _scrollToBottom(animate: false);
    }
    final itemCount = displayMessages.length + (_waitingForReply ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == displayMessages.length) return const _TypingBubble();
        return _MessageBubble(message: displayMessages[index]);
      },
    );
  }
}

/// Bolla "l'assistente sta scrivendo…", nel flusso della lista come un
/// messaggio in più — non un banner fisso sotto la lista.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadii.standard),
                topRight: Radius.circular(AppRadii.standard),
                bottomRight: Radius.circular(AppRadii.standard),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow:
                  AppShadows.card(isDark: theme.brightness == Brightness.dark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: AppSpacing.sm),
                Text('L\'assistente sta scrivendo…',
                    style: AppTypography.caption),
              ],
            ),
          ),
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
    // Al posto di `TextField(enabled: !isSending)`: disabilitare un campo che
    // ha il focus gli fa perdere il focus (e chiude la tastiera) ad ogni
    // invio, un secondo scatto indipendente da quello dello scroll. La
    // protezione da doppio invio resta, solo senza toccare il focus.
    if (ref.read(messageFormControllerProvider).isLoading ||
        _isUploadingPhoto) {
      return;
    }
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

    // Eco locale immediata: mostra subito la bolla dell'utente, senza
    // aspettare il giro di andata/ritorno di Realtime (vedi
    // optimisticMessageProvider in message_controller.dart).
    ref.read(optimisticMessageProvider(widget.chatId).notifier).state = Message(
      id: 'optimistic-${DateTime.now().microsecondsSinceEpoch}',
      chatId: widget.chatId,
      role: MessageRole.user,
      content: content.trim(),
      timestamp: DateTime.now(),
      attachmentIds: attachmentIds,
    );

    final failure = await ref.read(messageFormControllerProvider.notifier).send(
          chatId: widget.chatId,
          workspaceId: widget.transactionsWorkspaceId,
          content: content,
          attachmentIds: attachmentIds,
        );

    if (!mounted) return;
    // Se il messaggio reale non è ancora arrivato via Realtime a questo
    // punto (es. `send` fallito prima ancora di scrivere la riga utente),
    // non deve restare un'eco fantasma in lista.
    ref.read(optimisticMessageProvider(widget.chatId).notifier).state = null;
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
