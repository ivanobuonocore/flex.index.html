import 'package:pip_shared/pip_shared.dart';

import '../entities/task.dart';
import '../enums.dart';

/// Confine verso la persistenza delle Task, implementato nel layer `data` di
/// ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
abstract interface class TaskRepository {
  /// Task del Workspace [workspaceId], ordinate per data di creazione.
  Stream<List<Task>> watchTasks(String workspaceId);

  Future<Result<Task>> createTask({
    required String workspaceId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
  });

  Future<Result<Task>> updateTask(Task task);

  /// Soft delete (Domain Model, "Principi del modello").
  Future<Result<Unit>> deleteTask(String taskId);
}
