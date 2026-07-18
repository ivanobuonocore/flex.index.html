import '../enums.dart';

/// Conversazione con l'AI (Domain Model, entità Chat).
///
/// [workspaceId] è opzionale: una Chat può essere privata, non collegata a
/// nessun Workspace (docs/product/06-information-architecture.md, "Chat").
final class Chat {
  const Chat({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.aiModel,
    required this.status,
    required this.createdAt,
    this.workspaceId,
    this.lastMessageAt,
  });

  final String id;
  final String ownerId;
  final String? workspaceId;
  final String title;
  final String aiModel;
  final ChatStatus status;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  @override
  bool operator ==(Object other) =>
      other is Chat &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.workspaceId == workspaceId &&
      other.title == title &&
      other.aiModel == aiModel &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.lastMessageAt == lastMessageAt;

  @override
  int get hashCode => Object.hash(
        id,
        ownerId,
        workspaceId,
        title,
        aiModel,
        status,
        createdAt,
        lastMessageAt,
      );

  @override
  String toString() =>
      'Chat(id: $id, title: $title, workspaceId: $workspaceId)';
}
