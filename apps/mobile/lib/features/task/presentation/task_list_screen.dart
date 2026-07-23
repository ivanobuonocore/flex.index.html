import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../../shared/widgets/success_pulse.dart';
import '../../workspace/application/workspace_sharing_controller.dart';
import '../application/task_controller.dart';
import 'create_edit_task_sheet.dart';

/// Elenco completo delle Task di un Workspace
/// (docs/product/06-information-architecture.md, "Menu Workspace" — Attività).
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    // Permessi granulari sui Workspace condivisi (integrazione richiesta
    // esplicitamente): `null` per un Workspace personale o per il
    // proprietario di uno condiviso, sempre accesso pieno in entrambi i
    // casi — solo un membro con ruolo `viewer` viene limitato qui.
    final isViewer = ref.watch(currentMemberRoleProvider(workspaceId)) ==
        WorkspaceRole.viewer;

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Attività')),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  showCreateEditTaskSheet(context, workspaceId: workspaceId),
              child: const Icon(Icons.add),
            ),
      body: tasksAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le attività.',
          onRetry: () => ref.invalidate(tasksProvider(workspaceId)),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              color: AppColors.categoryAttivita,
              title: 'Nessuna attività ancora',
              message: isViewer
                  ? 'Non ci sono ancora attività in questo Workspace.'
                  : 'Crea la tua prima attività in questo Workspace.',
              action: isViewer
                  ? null
                  : FilledButton(
                      onPressed: () => showCreateEditTaskSheet(context,
                          workspaceId: workspaceId),
                      child: const Text('Crea la prima attività'),
                    ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isDone = task.status == TaskStatus.done;

              final card = Card(
                child: ListTile(
                  leading: SuccessPulse(
                    play: isDone,
                    child: Checkbox(
                      value: isDone,
                      activeColor: AppColors.categoryAttivita,
                      onChanged: isViewer
                          ? null
                          : (_) => ref
                              .read(taskFormControllerProvider.notifier)
                              .updateTask(
                                task.copyWith(
                                    status: isDone
                                        ? TaskStatus.todo
                                        : TaskStatus.done),
                              ),
                    ),
                  ),
                  title: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isDone
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  subtitle: task.description == null
                      ? null
                      : Text(task.description!,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: isViewer
                      ? null
                      : () => showCreateEditTaskSheet(
                            context,
                            workspaceId: workspaceId,
                            task: task,
                          ),
                ),
              );

              if (isViewer) return card;

              return Dismissible(
                key: ValueKey(task.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDeleteTask(context),
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
                    .read(taskFormControllerProvider.notifier)
                    .delete(task.id),
                child: card,
              );
            },
          );
        },
      ),
    );
  }
}

/// Conferma prima di eliminare un'attività (richiesta esplicita dell'utente:
/// "conferma su swipe-to-delete per elementi non banali") — a differenza del
/// toggle fatto/da fare, cancellare un'attività non è reversibile con un
/// secondo tocco.
Future<bool> _confirmDeleteTask(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminare questa attività?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Elimina'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
