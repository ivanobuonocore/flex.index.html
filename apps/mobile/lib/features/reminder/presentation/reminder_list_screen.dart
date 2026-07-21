import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../core/env/app_env.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../notifications/application/push_notification_controller.dart';
import '../../notifications/data/push_notification_service.dart';
import '../application/calendar_event_controller.dart';
import 'create_reminder_sheet.dart';

const _italianWeekdays = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
const _italianMonths = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Elenco completo dei Promemoria di un Workspace, con un calendario mensile
/// "a quadratini" in testa (richiesta esplicita dell'utente: "vorrei che si
/// vedesse un calendario fatto a quadratini (giorni) dove su ogni giorno
/// viene riportato l'appuntamento"). Toccare un giorno filtra l'elenco sotto
/// a quel giorno; senza alcun giorno selezionato l'elenco resta quello
/// completo di sempre, in ordine cronologico (Fase 3, "Promemoria via Chat").
class ReminderListScreen extends ConsumerStatefulWidget {
  const ReminderListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends ConsumerState<ReminderListScreen> {
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  // `null` = nessun filtro, l'elenco sotto mostra tutti i promemoria (stesso
  // comportamento di sempre) — il calendario è solo un modo aggiuntivo per
  // orientarsi, non l'unico.
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider(widget.workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Appuntamenti')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateReminderSheet(context, workspaceId: widget.workspaceId),
        child: const Icon(Icons.add),
      ),
      // Il banner delle notifiche resta fisso sopra la lista, indipendente da
      // loading/errore/dati (richiesta esplicita dell'utente: sapere subito
      // se i promemoria creati in Chat potranno davvero notificarla) —
      // nascosto del tutto se l'app non è stata compilata con una chiave
      // VAPID, come già in Profilo.
      body: Column(
        children: [
          if (AppEnv.vapidPublicKey.isNotEmpty)
            const _NotificationStatusBanner(),
          Expanded(
            child: eventsAsync.when(
              loading: () => const LoadingView(),
              error: (error, stackTrace) => ErrorView(
                message: 'Non è stato possibile caricare i promemoria.',
                onRetry: () =>
                    ref.invalidate(calendarEventsProvider(widget.workspaceId)),
              ),
              data: (events) {
                if (events.isEmpty) {
                  return EmptyState(
                    icon: Icons.notifications_outlined,
                    title: 'Nessun promemoria ancora',
                    message:
                        'Creane uno, oppure scrivi in Chat "ricordami di..." '
                        'e un orario: l\'assistente lo registra per te.',
                    action: FilledButton(
                      onPressed: () => showCreateReminderSheet(context,
                          workspaceId: widget.workspaceId),
                      child: const Text('Crea il primo promemoria'),
                    ),
                  );
                }

                final selectedDay = _selectedDay;
                final visibleEvents = selectedDay == null
                    ? events
                    : events
                        .where((e) =>
                            _isSameDay(e.startsAt.toLocal(), selectedDay))
                        .toList(growable: false);

                // SingleChildScrollView (non Column+Expanded): il calendario da
                // solo può già superare l'altezza disponibile su schermi piccoli
                // (6 righe di giorni + intestazione mese/settimana) — con
                // Expanded l'elenco sotto verrebbe schiacciato a zero pixel
                // invece di scorrere insieme al resto della pagina.
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _MonthCalendarGrid(
                        month: _visibleMonth,
                        selectedDay: selectedDay,
                        events: events,
                        onMonthChanged: (month) =>
                            setState(() => _visibleMonth = month),
                        onDaySelected: (day) => setState(() {
                          _selectedDay = (selectedDay != null &&
                                  _isSameDay(selectedDay, day))
                              ? null
                              : day;
                        }),
                      ),
                      const Divider(height: 1),
                      if (visibleEvents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'Nessun appuntamento in questo giorno.',
                            style: AppTypography.body.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: visibleEvents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final event = visibleEvents[index];
                            final isPast =
                                event.startsAt.isBefore(DateTime.now());

                            return Dismissible(
                              key: ValueKey(event.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: AppRadii.standardRadius,
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) => ref
                                  .read(calendarEventFormControllerProvider
                                      .notifier)
                                  .delete(event.id),
                              child: Card(
                                child: ListTile(
                                  leading: Icon(
                                    event.notifiedAt != null
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_none_outlined,
                                    color: isPast
                                        ? Theme.of(context).disabledColor
                                        : AppColors.categoryAppuntamenti,
                                  ),
                                  title: Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: isPast
                                        ? TextStyle(
                                            color:
                                                Theme.of(context).disabledColor)
                                        : null,
                                  ),
                                  subtitle:
                                      Text(_formatDateTime(event.startsAt)),
                                  // Badge "ricorrente" (richiesta esplicita
                                  // dell'utente: "promemoria ricorrenti") —
                                  // ogni occorrenza resta una riga
                                  // indipendente ed eliminabile singolarmente,
                                  // il badge è solo informativo.
                                  trailing: event.recurrenceGroupId != null
                                      ? Tooltip(
                                          message: 'Promemoria ricorrente',
                                          child: Icon(
                                            Icons.repeat,
                                            size: 18,
                                            color: isPast
                                                ? Theme.of(context)
                                                    .disabledColor
                                                : AppColors
                                                    .categoryAppuntamenti,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }
}

/// Avviso fisso in cima ad Appuntamenti sullo stato delle notifiche push
/// (richiesta esplicita dell'utente): un promemoria creato in Chat o qui
/// finisce comunque nel calendario, ma senza notifiche attive l'utente non
/// riceverebbe alcun avviso all'orario previsto — meglio dirlo subito che
/// scoprirlo dopo. Stessa infrastruttura già usata in Profilo
/// ([pushSupportStatusProvider]/[pushNotificationControllerProvider]), non
/// mostrato affatto se lo stato è già "attivo" (nulla da segnalare).
class _NotificationStatusBanner extends ConsumerWidget {
  const _NotificationStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(pushSupportStatusProvider);
    final isBusy = ref.watch(pushNotificationControllerProvider).isLoading;

    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status == PushSupportStatus.subscribed) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final message = status == PushSupportStatus.unsupported
            ? 'Le notifiche non sono supportate su questo dispositivo o '
                'browser: i promemoria compariranno comunque nel calendario, '
                'ma senza avviso all\'orario previsto.'
            : 'Notifiche non ancora attive: i promemoria compariranno nel '
                'calendario, ma non riceverai un avviso all\'orario previsto.';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
            borderRadius: AppRadii.standardRadius,
            border:
                Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_off_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(message, style: AppTypography.caption),
              ),
              if (status == PushSupportStatus.notSubscribed) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: isBusy ? null : () => _activate(context, ref),
                  child: const Text('Attiva'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(pushNotificationControllerProvider.notifier)
        .subscribe(AppEnv.vapidPublicKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? 'Notifiche attivate.')),
    );
  }
}

/// Calendario mensile "a quadratini": un giorno per cella, con un puntino
/// colorato sui giorni che hanno almeno un promemoria — non un semplice
/// elenco, così un impegno scritto in Chat (es. "lunedì prossimo devo andare
/// dal barbiere") si vede subito nel punto del calendario in cui cade.
class _MonthCalendarGrid extends StatelessWidget {
  const _MonthCalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: 1 (lunedì) .. 7 (domenica) — la settimana qui parte sempre di
    // lunedì, coerente con _italianWeekdays.
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;

    final eventCountByDay = <int, int>{};
    for (final event in events) {
      final local = event.startsAt.toLocal();
      if (local.year == month.year && local.month == month.month) {
        eventCountByDay[local.day] = (eventCountByDay[local.day] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1)),
              ),
              Text(
                '${_italianMonths[month.month - 1]} ${month.year}',
                style: AppTypography.heading3,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final label in _italianWeekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: AppTypography.caption.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (var day = 1; day <= daysInMonth; day++)
                _DayCell(
                  day: day,
                  isToday:
                      _isSameDay(DateTime(month.year, month.month, day), today),
                  isSelected: selectedDay != null &&
                      _isSameDay(
                          DateTime(month.year, month.month, day), selectedDay!),
                  eventCount: eventCountByDay[day] ?? 0,
                  onTap: () =>
                      onDaySelected(DateTime(month.year, month.month, day)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.eventCount,
    required this.onTap,
  });

  final int day;
  final bool isToday;
  final bool isSelected;
  final int eventCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.heroGradient[0];
    final hasEvent = eventCount > 0;

    // Richiesta esplicita dell'utente: il giorno di un appuntamento deve
    // essere "più caratteristico" (non un puntino minuscolo) — un cerchio
    // pieno, in una tinta più tenue del blu "selezionato" così restano
    // distinguibili tra loro. "Oggi" invece diventa il puntino piccolo,
    // indipendente dallo sfondo del giorno (mostrato anche se quel giorno
    // ha già il cerchio pieno per un appuntamento).
    final fillColor = isSelected
        ? accent
        : hasEvent
            ? Color.alphaBlend(
                accent.withOpacity(0.55), theme.colorScheme.surface)
            : Colors.transparent;
    final numberColor =
        (isSelected || hasEvent) ? Colors.white : theme.colorScheme.onSurface;
    final markerColor = (isSelected || hasEvent) ? Colors.white : accent;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: fillColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: AppTypography.body.copyWith(
                    color: numberColor,
                    fontWeight:
                        hasEvent || isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: markerColor,
                    ),
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
