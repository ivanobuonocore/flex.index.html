/// Nota testuale in un Workspace (Domain Model, entità Note).
final class Note {
  const Note({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.tags = const [],
    this.createdByAi = false,
    this.deletedAt,
  });

  final String id;
  final String workspaceId;
  final String title;
  final String content;
  final List<String> tags;
  final bool createdByAi;
  final DateTime updatedAt;

  /// Soft delete (Domain Model, "Principi del modello").
  final DateTime? deletedAt;

  Note copyWith({
    String? title,
    String? content,
    List<String>? tags,
    required DateTime updatedAt,
  }) {
    return Note(
      id: id,
      workspaceId: workspaceId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdByAi: createdByAi,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.title == title &&
      other.content == content &&
      other.createdByAi == createdByAi &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      _listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        title,
        content,
        createdByAi,
        updatedAt,
        deletedAt,
        Object.hashAll(tags),
      );

  @override
  String toString() =>
      'Note(id: $id, title: $title, workspaceId: $workspaceId)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
