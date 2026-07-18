/// Assistente AI specializzato, associabile a uno o più Workspace (Domain
/// Model, entità Agent; docs/product/06-information-architecture.md, "Agenti AI").
final class Agent {
  const Agent({
    required this.id,
    required this.name,
    required this.systemPrompt,
    required this.preferredAiModel,
    this.description,
    this.availableTools = const [],
    this.workspaceIds = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String systemPrompt;
  final List<String> availableTools;
  final String preferredAiModel;
  final List<String> workspaceIds;

  @override
  bool operator ==(Object other) =>
      other is Agent &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.systemPrompt == systemPrompt &&
      other.preferredAiModel == preferredAiModel &&
      _listEquals(other.availableTools, availableTools) &&
      _listEquals(other.workspaceIds, workspaceIds);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        systemPrompt,
        preferredAiModel,
        Object.hashAll(availableTools),
        Object.hashAll(workspaceIds),
      );

  @override
  String toString() => 'Agent(id: $id, name: $name)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
