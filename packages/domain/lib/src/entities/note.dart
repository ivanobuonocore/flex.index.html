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
  });

  final String id;
  final String workspaceId;
  final String title;
  final String content;
  final List<String> tags;
  final bool createdByAi;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.title == title &&
      other.content == content &&
      other.createdByAi == createdByAi &&
      other.updatedAt == updatedAt &&
      _listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        title,
        content,
        createdByAi,
        updatedAt,
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
