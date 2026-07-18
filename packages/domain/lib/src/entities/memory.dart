import '../enums.dart';

/// Informazione ricordata dall'AI su richiesta o inferenza (Domain Model,
/// entità Memory; Software Architecture, "Memoria AI — tre livelli").
///
/// Esattamente uno tra [userId], [workspaceId], [chatId] è valorizzato, in
/// coerenza con [level] (Domain Model, "Note tecniche da chiarire").
final class Memory {
  const Memory({
    required this.id,
    required this.content,
    required this.level,
    required this.origin,
    required this.updatedAt,
    this.userId,
    this.workspaceId,
    this.chatId,
  }) : assert(
          (level == MemoryLevel.global && userId != null) ||
              (level == MemoryLevel.workspace && workspaceId != null) ||
              (level == MemoryLevel.conversation && chatId != null),
          'Il livello della memoria deve corrispondere al proprietario valorizzato',
        );

  final String id;
  final String content;
  final MemoryLevel level;
  final MemoryOrigin origin;
  final String? userId;
  final String? workspaceId;
  final String? chatId;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Memory &&
      other.id == id &&
      other.content == content &&
      other.level == level &&
      other.origin == origin &&
      other.userId == userId &&
      other.workspaceId == workspaceId &&
      other.chatId == chatId &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        content,
        level,
        origin,
        userId,
        workspaceId,
        chatId,
        updatedAt,
      );

  @override
  String toString() => 'Memory(id: $id, level: $level, origin: $origin)';
}
