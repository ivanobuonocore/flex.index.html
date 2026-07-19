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
    this.deletedAt,
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

  /// Soft delete (Domain Model, "Principi del modello").
  final DateTime? deletedAt;

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueAt,
  }) {
    return Task(
      id: id,
      workspaceId: workspaceId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      assigneeId: assigneeId,
      generatedByAi: generatedByAi,
      documentId: documentId,
      chatId: chatId,
      createdAt: createdAt,
      deletedAt: deletedAt,
    );
  }

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
      other.createdAt == createdAt &&
      other.deletedAt == deletedAt;

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
        deletedAt,
      );

  @override
  String toString() => 'Task(id: $id, title: $title, status: $status)';
}
