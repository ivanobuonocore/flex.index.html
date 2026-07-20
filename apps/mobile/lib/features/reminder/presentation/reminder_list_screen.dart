import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/calendar_event_controller.dart';
import 'create_reminder_sheet.dart';

/// Elenco completo dei Promemoria di un Workspace (Fase 3, "Promemoria via
/// Chat" — CLAUDE.md, richiesta esplicita dell'utente).
class ReminderListScreen extends ConsumerWidget {
  const ReminderListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(calendarEventsProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Promemoria')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateReminderSheet(context, workspaceId: workspaceId),
        child: const Icon(Icons.add),
      ),
      body: eventsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare i promemoria.',
          onRetry: () => ref.invalidate(calendarEventsProvider(workspaceId)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_outlined,
              title: 'Nessun promemoria ancora',
              message: 'Creane uno, oppure scrivi in Chat "ricordami di..." '
                  'e un orario: l\'assistente lo registra per te.',
              action: FilledButton(
                onPressed: () =>
                    showCreateReminderSheet(context, workspaceId: workspaceId),
                child: const Text('Crea il primo promemoria'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final event = events[index];
              final isPast = event.startsAt.isBefore(DateTime.now());

              return Dismissible(
                key: ValueKey(event.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: AppRadii.standardRadius,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => ref
                    .read(calendarEventFormControllerProvider.notifier)
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
                          ? TextStyle(color: Theme.of(context).disabledColor)
                          : null,
                    ),
                    subtitle: Text(_formatDateTime(event.startsAt)),
                  ),
                ),
              );
            },
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
