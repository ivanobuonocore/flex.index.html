import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({this.createResult});

  final _controller = StreamController<List<Task>>.broadcast();
  Result<Task>? createResult;
  Task? lastCreated;
  Task? lastUpdated;
  String? lastDeletedId;

  void emit(List<Task> tasks) => _controller.add(tasks);

  @override
  Stream<List<Task>> watchTasks(String workspaceId) => _controller.stream;

  @override
  Future<Result<Task>> createTask({
    required String workspaceId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
  }) async {
    final result = createResult ??
        const Result<Task>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<Task>).value;
    }
    return result;
  }

  @override
  Future<Result<Task>> updateTask(Task task) async {
    lastUpdated = task;
    return Result.ok(task);
  }

  @override
  Future<Result<Unit>> deleteTask(String taskId) async {
    lastDeletedId = taskId;
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
