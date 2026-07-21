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
    this.themeMode = AppThemeMode.system,
  });

  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final UserPlan plan;
  final DateTime createdAt;
  final DateTime? lastSeenAt;

  /// Preferenza di tema (richiesta esplicita dell'utente: "tema chiaro/
  /// scuro"). Persistita lato identity provider (metadata dell'utenza), non
  /// una nuova tabella: è una preferenza globale, non legata a un Workspace.
  final AppThemeMode themeMode;

  User copyWith({
    String? name,
    String? avatarUrl,
    UserPlan? plan,
    DateTime? lastSeenAt,
    AppThemeMode? themeMode,
  }) {
    return User(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      plan: plan ?? this.plan,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      themeMode: themeMode ?? this.themeMode,
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
      other.lastSeenAt == lastSeenAt &&
      other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(
      id, email, name, avatarUrl, plan, createdAt, lastSeenAt, themeMode);

  @override
  String toString() => 'User(id: $id, email: $email, plan: $plan)';
}
