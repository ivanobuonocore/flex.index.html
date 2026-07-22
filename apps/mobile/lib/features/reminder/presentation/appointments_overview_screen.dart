import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/month_calendar_grid.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../workspace/application/workspace_controller.dart';
import '../application/calendar_event_controller.dart';

/// Appuntamenti globale (quarta voce della barra di navigazione, al posto
/// della Ricerca — richiesta esplicita dell'utente). A differenza di
/// [ReminderListScreen] (un solo Workspace), qui `workspaceId` è sempre
/// `null` — aggrega i promemoria di **tutti** i Workspace dell'utente in un
/// unico calendario, stesso principio già usato da [BalanceOverviewScreen]
/// per il Bilancio globale. Nessun FAB: un promemoria appartiene sempre a un
/// Workspace preciso, la creazione resta lì o via Chat — toccare una riga
/// apre il Workspace di origine per modificarla/eliminarla.
class AppointmentsOverviewScreen extends ConsumerStatefulWidget {
  const AppointmentsOverviewScreen({super.key});

  @override
  ConsumerState<AppointmentsOverviewScreen> createState() =>
      _AppointmentsOverviewScreenState();
}

class _AppointmentsOverviewScreenState
    extends ConsumerState<AppointmentsOverviewScreen> {
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  // `null` = nessun filtro, l'elenco sotto mostra tutti i promemoria (stesso
  // comportamento di ReminderListScreen).
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider(null));
    final workspacesAsync = ref.watch(workspacesProvider);

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Appuntamenti')),
      body: eventsAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare gli appuntamenti.',
          onRetry: () => ref.invalidate(calendarEventsProvider(null)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_outlined,
              color: AppColors.categoryAppuntamenti,
              title: 'Nessun appuntamento ancora',
              message: 'Scrivi in Chat "ricordami di..." e un orario, oppure '
                  'crea un promemoria da un Workspace: qui troverai il '
                  'quadro d\'insieme.',
            );
          }

          final workspaceNames = <String, String>{
            for (final workspace in workspacesAsync.value ?? const [])
              workspace.id: workspace.name,
          };

          final selectedDay = _selectedDay;
          final visibleEvents = selectedDay == null
              ? events
              : events
                  .where((e) =>
                      isSameCalendarDay(e.startsAt.toLocal(), selectedDay))
                  .toList(growable: false);

          // SingleChildScrollView (non Column+Expanded): stesso motivo già
          // documentato in ReminderListScreen — il calendario da solo può
          // già superare l'altezza disponibile su schermi piccoli.
          return SingleChildScrollView(
            child: Column(
              children: [
                MonthCalendarGrid(
                  month: _visibleMonth,
                  selectedDay: selectedDay,
                  events: events,
                  onMonthChanged: (month) =>
                      setState(() => _visibleMonth = month),
                  onDaySelected: (day) => setState(() {
                    _selectedDay = (selectedDay != null &&
                            isSameCalendarDay(selectedDay, day))
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
                      final isPast = event.startsAt.isBefore(DateTime.now());

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.notifications_none_outlined,
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
                                    color: Theme.of(context).disabledColor)
                                : null,
                          ),
                          subtitle: Text(
                            '${_formatDateTime(event.startsAt)} · '
                            '${workspaceNames[event.workspaceId] ?? 'Workspace'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                              '/workspace/${event.workspaceId}/reminders'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
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
