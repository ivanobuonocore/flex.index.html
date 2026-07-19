import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Attività')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateEditTaskSheet(context, workspaceId: workspaceId),
        child: const Icon(Icons.add),
      ),
      body: tasksAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le attività.',
          onRetry: () => ref.invalidate(tasksProvider(workspaceId)),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Nessuna attività ancora',
              message: 'Crea la tua prima attività in questo Workspace.',
              action: FilledButton(
                onPressed: () =>
                    showCreateEditTaskSheet(context, workspaceId: workspaceId),
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

              return Dismissible(
                key: ValueKey(task.id),
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
                    .read(taskFormControllerProvider.notifier)
                    .delete(task.id),
                child: Card(
                  child: ListTile(
                    leading: Checkbox(
                      value: isDone,
                      onChanged: (_) => ref
                          .read(taskFormControllerProvider.notifier)
                          .updateTask(
                            task.copyWith(
                                status:
                                    isDone ? TaskStatus.todo : TaskStatus.done),
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
                    onTap: () => showCreateEditTaskSheet(
                      context,
                      workspaceId: workspaceId,
                      task: task,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
