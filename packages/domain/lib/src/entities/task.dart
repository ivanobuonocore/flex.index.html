import '../enums.dart';

/// Attività da svolgere in un Workspace (Domain Model, entità Task).
final class Task {
  const Task({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.description,
    this.dueAt,
    this.assigneeId,
    this.generatedByAi = false,
    this.documentId,
    this.chatId,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueAt;

  /// Solo per Workspace condivisi (Business). Null in un Workspace personale.
  final String? assigneeId;
  final bool generatedByAi;
  final String? documentId;
  final String? chatId;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.title == title &&
      other.description == description &&
      other.status == status &&
      other.priority == priority &&
      other.dueAt == dueAt &&
      other.assigneeId == assigneeId &&
      other.generatedByAi == generatedByAi &&
      other.documentId == documentId &&
      other.chatId == chatId &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        title,
        description,
        status,
        priority,
        dueAt,
        assigneeId,
        generatedByAi,
        documentId,
        chatId,
        createdAt,
      );

  @override
  String toString() => 'Task(id: $id, title: $title, status: $status)';
}
