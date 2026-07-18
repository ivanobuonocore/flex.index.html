import '../enums.dart';

/// Utente della piattaforma (Domain Model, entità User).
///
/// Risorsa globale, non appartiene a un Workspace (CLAUDE.md, Principi
/// architetturali non negoziabili: "salvo risorse esplicitamente globali").
final class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.plan,
    required this.createdAt,
    this.avatarUrl,
    this.lastSeenAt,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final UserPlan plan;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  User copyWith({
    String? name,
    String? avatarUrl,
    UserPlan? plan,
    DateTime? lastSeenAt,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.email == email &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      other.plan == plan &&
      other.createdAt == createdAt &&
      other.lastSeenAt == lastSeenAt;

  @override
  int get hashCode =>
      Object.hash(id, email, name, avatarUrl, plan, createdAt, lastSeenAt);

  @override
  String toString() => 'User(id: $id, email: $email, plan: $plan)';
}
