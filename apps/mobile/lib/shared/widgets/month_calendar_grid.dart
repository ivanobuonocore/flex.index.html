import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

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

/// Stesso giorno di calendario (anno/mese/giorno), indipendente dall'orario —
/// condiviso tra `ReminderListScreen` (un Workspace) e
/// `AppointmentsOverviewScreen` (tutti i Workspace).
bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calendario mensile "a quadratini": un giorno per cella, con un puntino
/// colorato sui giorni che hanno almeno un promemoria — non un semplice
/// elenco, così un impegno scritto in Chat (es. "lunedì prossimo devo andare
/// dal barbiere") si vede subito nel punto del calendario in cui cade.
/// Estratto da `reminder_list_screen.dart` (era `_MonthCalendarGrid`) per
/// essere riusato anche dalla schermata Appuntamenti globale.
class MonthCalendarGrid extends StatelessWidget {
  const MonthCalendarGrid({
    super.key,
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
                  isToday: isSameCalendarDay(
                      DateTime(month.year, month.month, day), today),
                  isSelected: selectedDay != null &&
                      isSameCalendarDay(
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
    // Il giorno selezionato e gli appuntamenti usano il viola del sistema:
    // evita qualsiasi richiamo arancione e resta coerente con l'header
    // blu → viola della schermata Appuntamenti.
    final accent = AppColors.heroGradient.last;
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

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: reduceMotion ? AppMotion.instant : AppMotion.fast,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          boxShadow: isSelected && !reduceMotion
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
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
    ),
  );
  }
}
