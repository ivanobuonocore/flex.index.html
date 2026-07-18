/// Evento della cronologia di un Workspace, riferibile a qualsiasi altra
/// entità tramite un pattern polimorfico esplicito (Domain Model, entità
/// Timeline Event e "Note tecniche da chiarire").
final class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.workspaceId,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.authorId,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  final String id;
  final String workspaceId;
  final String type;
  final String description;
  final DateTime timestamp;
  final String authorId;

  /// Nome dell'entità collegata (es. "task", "document"), coppia con [relatedEntityId].
  final String? relatedEntityType;
  final String? relatedEntityId;

  @override
  bool operator ==(Object other) =>
      other is TimelineEvent &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.type == type &&
      other.description == description &&
      other.timestamp == timestamp &&
      other.authorId == authorId &&
      other.relatedEntityType == relatedEntityType &&
      other.relatedEntityId == relatedEntityId;

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        type,
        description,
        timestamp,
        authorId,
        relatedEntityType,
        relatedEntityId,
      );

  @override
  String toString() =>
      'TimelineEvent(id: $id, type: $type, workspaceId: $workspaceId)';
}
