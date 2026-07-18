import '../enums.dart';

/// Un progetto dell'utente: il confine logico del sistema (Domain Model,
/// entità Workspace; Architectural Principles, Principio 3).
///
/// Ogni altra risorsa (Chat, Document, Task, Note, Memory, ...) appartiene a
/// esattamente un Workspace tramite [ownerId] a livello di autorizzazione e
/// [id] come chiave esterna.
final class Workspace {
  const Workspace({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.icon,
    required this.status,
    required this.createdAt,
    this.description,
    this.category,
    this.color,
  });

  final String id;

  /// [User.id] del proprietario. Applicato anche via RLS lato Supabase.
  final String ownerId;
  final String name;
  final String? description;
  final String icon;
  final String? category;
  final WorkspaceStatus status;

  /// Colore facoltativo (Domain Model, entità Workspace).
  final String? color;
  final DateTime createdAt;

  Workspace copyWith({
    String? name,
    String? description,
    String? icon,
    String? category,
    WorkspaceStatus? status,
    String? color,
  }) {
    return Workspace(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      status: status ?? this.status,
      color: color ?? this.color,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Workspace &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.name == name &&
      other.description == description &&
      other.icon == icon &&
      other.category == category &&
      other.status == status &&
      other.color == color &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        ownerId,
        name,
        description,
        icon,
        category,
        status,
        color,
        createdAt,
      );

  @override
  String toString() => 'Workspace(id: $id, name: $name, status: $status)';
}
