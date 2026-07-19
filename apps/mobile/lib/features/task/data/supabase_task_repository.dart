import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [TaskRepository] su Supabase Postgres. L'isolamento tra
/// Workspace è garantito dalle policy RLS di `tasks`
/// (`infrastructure/supabase/migrations`), che verificano il Workspace
/// referenziato — non da un filtro applicativo qui sotto.
class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'tasks';

  @override
  Stream<List<Task>> watchTasks(String workspaceId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Task>> createTask({
    required String workspaceId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueAt,
  }) async {
    if (title.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('Il titolo della task è obbligatorio.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'workspace_id': workspaceId,
            'title': title.trim(),
            'description': description,
            'priority': _priorityToDb(priority),
            'due_at': dueAt?.toIso8601String(),
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
          UnexpectedFailure('Non è stato possibile creare la task.', cause: e));
    }
  }

  @override
  Future<Result<Task>> updateTask(Task task) async {
    try {
      final row = await _client
          .from(_table)
          .update({
            'title': task.title,
            'description': task.description,
            'status': _statusToDb(task.status),
            'priority': _priorityToDb(task.priority),
            'due_at': task.dueAt?.toIso8601String(),
          })
          .eq('id', task.id)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aggiornare la task.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteTask(String taskId) async {
    try {
      await _client.from(_table).update(
          {'deleted_at': DateTime.now().toIso8601String()}).eq('id', taskId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare la task.', cause: e),
      );
    }
  }

  Task _toDomain(Map<String, dynamic> row) {
    return Task(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      status: _statusFromDb(row['status'] as String),
      priority: _priorityFromDb(row['priority'] as String),
      dueAt: row['due_at'] != null
          ? DateTime.parse(row['due_at'] as String)
          : null,
      assigneeId: row['assignee_id'] as String?,
      generatedByAi: row['generated_by_ai'] as bool,
      documentId: row['document_id'] as String?,
      chatId: row['chat_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }

  String _statusToDb(TaskStatus status) => switch (status) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
      };

  TaskStatus _statusFromDb(String value) => switch (value) {
        'todo' => TaskStatus.todo,
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        _ => throw ArgumentError('Stato task sconosciuto: $value'),
      };

  String _priorityToDb(TaskPriority priority) => priority.name;

  TaskPriority _priorityFromDb(String value) =>
      TaskPriority.values.byName(value);
}
