import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/providers.dart';
import '../../../shared/widgets/document_thumbnail.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/session_controller.dart';
import '../../reminder/application/calendar_event_controller.dart';
import '../../task/application/task_controller.dart';
import '../../transaction/application/transaction_controller.dart';
import '../../workspace/application/workspace_category_meta.dart';
import '../../workspace/application/workspace_controller.dart';
import '../../workspace/presentation/widgets/section_preview.dart';
import '../application/chat_controller.dart';
import '../application/markdown_lite.dart';
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
      appBar: GradientAppBar(title: Text(_greeting(user?.name))),
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

class _ChatHomeBody extends ConsumerStatefulWidget {
  const _ChatHomeBody({required this.chatId});

  final String chatId;

  @override
  ConsumerState<_ChatHomeBody> createState() => _ChatHomeBodyState();
}

class _ChatHomeBodyState extends ConsumerState<_ChatHomeBody> {
  // Richiesta esplicita dell'utente: "la sezione che riporta le workspace
  // vorrei fosse nascondibile" — non tocca i dati, solo quanto spazio la
  // striscia occupa sopra la conversazione.
  bool _sectionsCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final chatId = widget.chatId;
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final sections = <Workspace>[
      for (final category in SystemWorkspaceCategory.all)
        ...workspaces.where((w) => w.category == category),
    ];
    // Le transazioni scritte in Chat vanno sempre nella sezione Bilancio, le
    // foto sempre in Documenti, i promemoria sempre in Appuntamenti —
    // indipendentemente da dove si trovano nella lista (Fase 3, slice 7A ha
    // già reso questi id stabili e unici per categoria). `null` finché il
    // bootstrap non ha ancora creato le sezioni.
    final bilancioId =
        _idForCategory(workspaces, SystemWorkspaceCategory.bilancio);
    final documentiId =
        _idForCategory(workspaces, SystemWorkspaceCategory.documenti);
    final appuntamentiId =
        _idForCategory(workspaces, SystemWorkspaceCategory.appuntamenti);
    final attivitaId =
        _idForCategory(workspaces, SystemWorkspaceCategory.attivita);

    return Column(
      children: [
        _TodayHighlights(
          bilancioId: bilancioId,
          appuntamentiId: appuntamentiId,
          attivitaId: attivitaId,
        ),
        if (sections.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              // Leggero gradiente verticale invece di un colore piatto
              // (redesign estetico 2.0): stessa superficie di prima, solo con
              // più profondità.
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: AppShadows.card(
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _sectionsCollapsed = !_sectionsCollapsed),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sezioni',
                          style: AppTypography.caption
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Icon(
                          _sectionsCollapsed
                              ? Icons.expand_more
                              : Icons.expand_less,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                // Più sottile e leggera della card completa usata nella tab
                // Workspace (richiesta esplicita dell'utente: "più sottile ed
                // esteticamente più bella ed intuitiva") — solo icona, nome e
                // anteprima, senza il menu Rinomina/Elimina: qui è una
                // scorciatoia di lettura, non il posto da cui gestire un
                // Workspace.
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _sectionsCollapsed
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: SizedBox(
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
                const SizedBox(height: AppSpacing.xs),
              ],
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
            // Macchie di colore sfumate sullo sfondo (redesign estetico 2.0 —
            // richiesta esplicita dell'utente: "molto tecnologica"): danno
            // profondità a uno sfondo altrimenti piatto, senza interferire
            // con la leggibilità delle bolle sopra (IgnorePointer: sono solo
            // decorative, non devono intercettare lo scroll/i tap).
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -50,
                  child: _GlowBlob(color: AppColors.heroGradient.first),
                ),
                Positioned(
                  bottom: -80,
                  left: -60,
                  child: _GlowBlob(color: AppColors.heroGradient.last),
                ),
                _MessagesArea(chatId: chatId),
              ],
            ),
          ),
        ),
        _MessageInput(
          chatId: chatId,
          transactionsWorkspaceId: bilancioId,
          documentsWorkspaceId: documentiId,
          remindersWorkspaceId: appuntamentiId,
          tasksWorkspaceId: attivitaId,
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

/// Blocco "Oggi" (richiesta esplicita dell'utente, dopo aver scartato una tab
/// dedicata — `docs/product/06-information-architecture.md` l'aveva già
/// esclusa in passato): riusa solo provider/funzioni pure già esistenti,
/// nessuna nuova query. Ogni riga compare solo se ha qualcosa da mostrare; se
/// non c'è nulla (nessun impegno oggi, nessuna attività aperta, nessuna
/// transazione questo mese) il blocco non occupa spazio — stesso principio
/// già usato per `_NotificationStatusBanner` in `reminder_list_screen.dart`.
class _TodayHighlights extends ConsumerWidget {
  const _TodayHighlights({
    required this.bilancioId,
    required this.appuntamentiId,
    required this.attivitaId,
  });

  final String? bilancioId;
  final String? appuntamentiId;
  final String? attivitaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    CalendarEvent? nextEventToday;
    if (appuntamentiId != null) {
      // `.asData?.value`, non `.value`: quest'ultimo rilancia l'eccezione
      // originale su uno stato di errore (es. `calendarEventRepositoryProvider`
      // non sovrascritto nei test, o un Workspace non ancora bootstrappato) —
      // il blocco "Oggi" deve solo non mostrare quella riga, mai far fallire
      // l'intera Chat Home per un provider secondario.
      final events =
          ref.watch(calendarEventsProvider(appuntamentiId!)).asData?.value ??
              const [];
      final today = remindersDueToday(events)
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      nextEventToday = today.isEmpty ? null : today.first;
    }

    var openTasksCount = 0;
    if (attivitaId != null) {
      final tasks =
          ref.watch(tasksProvider(attivitaId!)).asData?.value ?? const [];
      openTasksCount = openTasks(tasks).length;
    }

    int? projectedCents;
    if (bilancioId != null) {
      final transactions =
          ref.watch(transactionsProvider(bilancioId!)).asData?.value ??
              const [];
      final confirmed = confirmedThisMonth(transactions, now: now);
      if (confirmed.isNotEmpty) {
        projectedCents = projectedMonthEndExpenseCents(
          spentSoFarCents: totalExpenseCents(confirmed),
          now: now,
        );
      }
    }

    final rows = <Widget>[
      if (nextEventToday != null)
        _TodayRow(
          icon: Icons.event_outlined,
          text: 'Prossimo: ${nextEventToday.title} alle '
              '${_formatEventTime(nextEventToday.startsAt)}',
          onTap: () => context.push('/workspace/$appuntamentiId/reminders'),
        ),
      if (openTasksCount > 0)
        _TodayRow(
          icon: Icons.checklist_outlined,
          text: openTasksCount == 1
              ? '1 attività da fare'
              : '$openTasksCount attività da fare',
          onTap: () => context.push('/workspace/$attivitaId/tasks'),
        ),
      if (projectedCents != null)
        _TodayRow(
          icon: Icons.trending_up,
          text: 'Proiezione fine mese: ${_formatEventAmount(projectedCents)}',
          onTap: () => context.push('/balance'),
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.standardRadius,
        boxShadow: AppShadows.glow(
          color: AppColors.heroGradient.first,
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            rows[i],
          ],
        ],
      ),
    );
  }

  String _formatEventTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatEventAmount(int amountCents) =>
      '${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.buttonRadius,
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sezione fissa nella striscia in testa alla Chat: solo icona colorata,
/// nome e anteprima viva — nessun menu (quello resta nella tab Workspace).
class _SectionChip extends ConsumerWidget {
  const _SectionChip({required this.workspace});

  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = WorkspaceCategoryMeta.of(workspace.category);
    final tint = meta?.color ?? Theme.of(context).colorScheme.primary;
    final icon = meta?.icon ?? Icons.folder_outlined;

    // Badge coi promemoria di oggi (richiesta esplicita dell'utente: "badge
    // sulla tab Appuntamenti") — solo per la sezione Appuntamenti, non
    // osserva `calendarEventsProvider` per le altre (nessuna sottoscrizione
    // in più senza motivo).
    final remindersToday =
        workspace.category == SystemWorkspaceCategory.appuntamenti
            ? ref.watch(calendarEventsProvider(workspace.id)).maybeWhen(
                  data: (events) => remindersDueToday(events).length,
                  orElse: () => 0,
                )
            : 0;

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.buttonRadius,
      child: InkWell(
        borderRadius: AppRadii.buttonRadius,
        // La sezione Appuntamenti apre direttamente il calendario
        // (richiesta esplicita dell'utente: "vorrei vedere il calendario"),
        // non l'anteprima generica del Workspace — da lì era raggiungibile
        // solo con un tocco in più su "vedi tutti".
        onTap: () => GoRouter.of(context).push(
          workspace.category == SystemWorkspaceCategory.appuntamenti
              ? '/workspace/${workspace.id}/reminders'
              : '/workspace/${workspace.id}',
        ),
        child: Container(
          // Sfondo sfumato tenue nel colore della categoria + bordo sottile
          // (redesign estetico 2.0): dà rilievo alla singola sezione senza
          // la pesantezza di un alone diffuso (riservato agli elementi
          // "hero", vedi AppShadows.glow).
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tint.withOpacity(0.16), tint.withOpacity(0.04)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.buttonRadius,
            border: Border.all(color: tint.withOpacity(0.25)),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: remindersToday > 0,
                label: Text('$remindersToday'),
                backgroundColor: AppColors.error,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [tint, tint.withOpacity(0.65)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
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

/// Macchia di colore sfumata e decorativa (vedi commento sopra, nello sfondo
/// della Chat) — `IgnorePointer` perché non deve mai intercettare tap/scroll.
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.16), color.withOpacity(0.0)],
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

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    // Bianco fisso per il testo dell'utente (non `onPrimary`, che in dark
    // mode è pensato per un primary chiaro, non per il gradiente scuro
    // heroGradient usato qui sotto — vedi decoration della bolla): il
    // gradiente è lo stesso in entrambi i temi (come siriGlow), quindi anche
    // il contrasto del testo resta costante.
    final textColor = isUser ? Colors.white : theme.colorScheme.onSurface;

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
        // Gradiente "premium" solo per le bolle dell'utente (redesign
        // estetico 2.0): quelle dell'assistente restano una superficie
        // piatta, per non perdere il contrasto visivo tra i due mittenti che
        // già distingue la conversazione a colpo d'occhio.
        color: isUser ? null : theme.colorScheme.surfaceContainerHighest,
        gradient: isUser
            ? const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: bubbleRadius,
        boxShadow: AppShadows.card(isDark: theme.brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final attachmentId in message.attachmentIds) ...[
            DocumentThumbnail(documentId: attachmentId),
            const SizedBox(height: AppSpacing.xs),
          ],
          _MessageText(content: message.content, color: textColor),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          // Conferma/Scarta subito sotto la risposta dell'assistente
          // (richiesta esplicita dell'utente: "azioni rapide sulle
          // transazioni pending direttamente in chat") — solo per i
          // messaggi che hanno davvero generato transazioni ancora in
          // attesa di conferma (un id può non esserlo più: già
          // confermato/scartato da qui o dal Bilancio).
          if (!isUser && message.pendingTransactionIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  left: 28 + AppSpacing.xs, top: AppSpacing.xs),
              child: _PendingTransactionActions(
                transactionIds: message.pendingTransactionIds,
              ),
            ),
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

/// Contenuto di una bolla di messaggio, con grassetto/elenchi puntati
/// (`markdown_lite.dart`) quando presenti. Resta un `Text` semplice quando il
/// contenuto non ha alcun marcatore — il caso comune, incluso ogni messaggio
/// dell'utente e ogni fixture di test esistente — perché `find.text(...)`
/// (usato in tutta `chat_home_screen_test.dart`) non trova testo dentro un
/// `Text.rich`/`RichText` per difetto: passare sempre a `Text.rich`
/// romperebbe quelle asserzioni.
class _MessageText extends StatelessWidget {
  const _MessageText({required this.content, required this.color});

  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!containsMarkdownLite(content)) {
      return Text(content, style: AppTypography.body.copyWith(color: color));
    }

    final lines = parseMarkdownLite(content);
    return Text.rich(
      TextSpan(
        style: AppTypography.body.copyWith(color: color),
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (lines[i].isBullet) const TextSpan(text: '•  '),
            for (final span in lines[i].spans)
              TextSpan(
                text: span.text,
                style: span.bold
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
            if (i < lines.length - 1) const TextSpan(text: '\n'),
          ],
        ],
      ),
    );
  }
}

/// Piccolo avatar per i messaggi dell'assistente — dà un punto di riferimento
/// visivo a colpo d'occhio (stile app di messaggistica), senza bisogno di
/// un'immagine da caricare: solo un'icona su un cerchio colorato.
class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    // Gradiente al posto del secondaryContainer piatto (redesign estetico
    // 2.0): stessa famiglia cromatica delle bolle dell'utente e dell'AppBar,
    // così l'assistente è riconoscibile a colpo d'occhio ovunque compaia.
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.heroGradient.first.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
    );
  }
}

/// Conferma/Scarta inline per le Transazioni pending generate da un messaggio
/// (richiesta esplicita dell'utente): riusa lo stesso
/// `transactionFormControllerProvider` del Bilancio, nessuna nuova azione da
/// costruire. Filtra sempre per `status == pending` al momento della
/// lettura: un id già confermato/scartato (da qui o dal Bilancio) smette
/// semplicemente di comparire, senza dover aggiornare il messaggio.
class _PendingTransactionActions extends ConsumerWidget {
  const _PendingTransactionActions({required this.transactionIds});

  final List<String> transactionIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider(null)).value ?? [];
    final idSet = transactionIds.toSet();
    final pending = transactions
        .where((t) =>
            idSet.contains(t.id) && t.status == TransactionStatus.pending)
        .toList(growable: false);

    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final transaction in pending) ...[
          _PendingTransactionActionTile(transaction: transaction),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _PendingTransactionActionTile extends ConsumerWidget {
  const _PendingTransactionActionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final isBusy = ref.watch(transactionFormControllerProvider).isLoading;

    return Container(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.buttonRadius,
        boxShadow: AppShadows.card(isDark: theme.brightness == Brightness.dark),
      ),
      child: Row(
        children: [
          Text(isIncome ? '💰' : '💸', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                Text(_formatAmount(transaction.amountCents),
                    style: AppTypography.caption),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, size: 20),
            tooltip: 'Conferma',
            onPressed: isBusy
                ? null
                : () => ref
                    .read(transactionFormControllerProvider.notifier)
                    .confirm(transaction.id),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Scarta',
            onPressed: isBusy
                ? null
                : () => ref
                    .read(transactionFormControllerProvider.notifier)
                    .delete(transaction.id),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amountCents) =>
      '${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
}

class _MessageInput extends ConsumerStatefulWidget {
  const _MessageInput({
    required this.chatId,
    required this.transactionsWorkspaceId,
    required this.documentsWorkspaceId,
    required this.remindersWorkspaceId,
    required this.tasksWorkspaceId,
  });

  final String chatId;

  /// Sezione Bilancio dell'utente: passata come contesto all'Edge Function
  /// `ai-chat` per abilitare `extract_transactions` (Fase 3, slice 2) — le
  /// transazioni riconosciute in Chat vanno sempre lì.
  final String? transactionsWorkspaceId;

  /// Sezione Documenti dell'utente: dove finisce una foto allegata (diverso
  /// da [transactionsWorkspaceId] — sono due sezioni fisse distinte).
  final String? documentsWorkspaceId;

  /// Sezione Appuntamenti dell'utente: passata come contesto all'Edge
  /// Function `ai-chat` per abilitare `create_reminder` (Fase 3, "Promemoria
  /// via Chat") — un promemoria riconosciuto in Chat va sempre lì, mai nella
  /// sezione Bilancio.
  final String? remindersWorkspaceId;

  /// Sezione Attività dell'utente: passata come contesto all'Edge Function
  /// `ai-chat` per abilitare `manage_tasks` (richiesta esplicita dell'utente:
  /// "liste/checklist via Chat") — un elemento di lista riconosciuto in Chat
  /// va sempre lì come Task, mai nella sezione Bilancio/Appuntamenti.
  final String? tasksWorkspaceId;

  @override
  ConsumerState<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<_MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _errorMessage;
  PlatformFile? _pendingPhoto;
  bool _isUploadingPhoto = false;
  bool _showEmojiPicker = false;

  // Dettatura vocale (integrazione richiesta esplicitamente). `SpeechToText`
  // risolve da sé l'implementazione per piattaforma (canale nativo su
  // mobile/desktop, Web Speech API su web tramite il plugin federato
  // `speech_to_text_web`) — nessun ramo `kIsWeb` scritto a mano qui.
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  bool get _canAttachPhoto => widget.documentsWorkspaceId != null;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  /// Il pulsante di dettatura compare solo se `initialize()` ha successo:
  /// niente bottone che poi fallisce silenziosamente al tocco (richiesta
  /// esplicita, rischio segnalato: il supporto varia per browser — buono su
  /// Chrome/Edge, spesso assente su Safari). Su mobile `initialize()` è
  /// anche il punto in cui viene richiesto il permesso microfono a runtime.
  /// Un errore qui (piattaforma senza plugin registrato, API non
  /// disponibile) equivale semplicemente a "non disponibile", non a un
  /// crash: stesso trattamento del caso "API assente".
  Future<void> _initSpeech() async {
    var available = false;
    try {
      available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      available = false;
    }
    if (mounted) setState(() => _speechAvailable = available);
  }

  /// Avvia/ferma la dettatura. Il testo trascritto sostituisce in tempo
  /// reale il contenuto del campo — l'utente vede e può correggere prima di
  /// inviare ("l'AI suggerisce, l'utente decide", stesso principio già
  /// applicato al resto della Chat, qui per la trascrizione).
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    try {
      await _speech.listen(
        onResult: (result) {
          _controller.value = TextEditingValue(
            text: result.recognizedWords,
            selection:
                TextSelection.collapsed(offset: result.recognizedWords.length),
          );
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    if (_isListening) _speech.stop();
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

    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }
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
          remindersWorkspaceId: widget.remindersWorkspaceId,
          tasksWorkspaceId: widget.tasksWorkspaceId,
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

    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      // Barra "flottante" con angoli superiori arrotondati e ombra (redesign
      // estetico 2.0): separa visivamente l'input dallo sfondo della Chat
      // invece di un semplice padding trasparente.
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.cardPremium)),
          boxShadow:
              AppShadows.card(isDark: theme.brightness == Brightness.dark),
        ),
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
                if (_speechAvailable)
                  IconButton(
                    tooltip:
                        _isListening ? 'Ferma dettatura' : 'Dettatura vocale',
                    onPressed: isSending ? null : _toggleListening,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_outlined,
                      color: _isListening ? theme.colorScheme.error : null,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Scrivi un messaggio…',
                      // Sfondo del campo distinto da quello della barra
                      // (entrambi altrimenti "surface"): senza questo, il
                      // redesign 2.0 della barra flottante annullerebbe il
                      // contrasto che rendeva il campo riconoscibile.
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
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
