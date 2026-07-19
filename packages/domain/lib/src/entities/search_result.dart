import '../enums.dart';

/// Un elemento trovato dalla Ricerca Universale
/// (docs/product/06-information-architecture.md, "Ricerca" — "Cercando ...
/// si trovano contemporaneamente: ... workspace, attività, ... note, ...").
///
/// A differenza delle altre entità non è un dato persistito: è un read-model
/// derivato da una query cross-tabella (vedi `SearchRepository`).
final class SearchResult {
  const SearchResult({
    required this.type,
    required this.id,
    required this.workspaceId,
    required this.title,
    this.snippet,
  });

  final SearchResultType type;
  final String id;

  /// Per [SearchResultType.workspace] coincide con [id].
  final String workspaceId;
  final String title;
  final String? snippet;

  @override
  bool operator ==(Object other) =>
      other is SearchResult &&
      other.type == type &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.title == title &&
      other.snippet == snippet;

  @override
  int get hashCode => Object.hash(type, id, workspaceId, title, snippet);

  @override
  String toString() => 'SearchResult(type: $type, id: $id, title: $title)';
}
