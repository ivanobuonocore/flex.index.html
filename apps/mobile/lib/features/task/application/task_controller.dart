import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Task di un Workspace, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final tasksProvider =
    StreamProvider.autoDispose.family<List<Task>, String>((ref, workspaceId) {
  return ref.watch(taskRepositoryProvider).watchTasks(workspaceId);
});

/// Attività non ancora completate — funzione pura (richiesta esplicita
/// dell'utente: blocco "Oggi" in Chat Home), condivisa con
/// `section_preview.dart`'s `_AttivitaPreview` invece di duplicare lo stesso
/// filtro in due punti.
List<Task> openTasks(List<Task> tasks) =>
    tasks.where((t) => t.status != TaskStatus.done).toList(growable: false);

final taskFormControllerProvider =
    AsyncNotifierProvider.autoDispose<TaskFormController, void>(
        TaskFormController.new);

class TaskFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String workspaceId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(taskRepositoryProvider).createTask(
          workspaceId: workspaceId,
          title: title,
          description: description,
          priority: priority,
          dueAt: dueAt,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> updateTask(Task task) async {
    state = const AsyncLoading();
    final result = await ref.read(taskRepositoryProvider).updateTask(task);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> delete(String taskId) async {
    state = const AsyncLoading();
    final result = await ref.read(taskRepositoryProvider).deleteTask(taskId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
