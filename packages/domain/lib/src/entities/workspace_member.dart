import '../enums.dart';

/// Appartenenza di un secondo utente a un Workspace altrui (Fase 3, "Bilancio
/// condiviso" — richiesta esplicita dell'utente: due Bilanci, uno personale e
/// uno condiviso con un'altra persona; estesa da "Note/Attività condivise" —
/// richiesta esplicita dell'utente). Non introduce Workspace condivisi in
/// generale: la condivisione vale per Transazioni, Note e Attività di quel
/// Workspace (RLS aggiuntiva per ciascuna, vedi migrazioni), i Documenti
/// restano visibili solo al proprietario.
final class WorkspaceMember {
  const WorkspaceMember({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.joinedAt,
    this.role = WorkspaceRole.editor,
  });

  final String id;
  final String workspaceId;

  /// [User.id] del membro (non il proprietario del Workspace).
  final String userId;
  final DateTime joinedAt;

  /// Permessi granulari (integrazione richiesta esplicitamente): `editor`
  /// (default) ha gli stessi diritti di scrittura del proprietario, `viewer`
  /// solo lettura. Modificabile solo dal proprietario
  /// ([WorkspaceSharingRepository.updateMemberRole]).
  final WorkspaceRole role;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceMember &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.userId == userId &&
      other.joinedAt == joinedAt &&
      other.role == role;

  @override
  int get hashCode => Object.hash(id, workspaceId, userId, joinedAt, role);

  @override
  String toString() =>
      'WorkspaceMember(id: $id, workspaceId: $workspaceId, userId: $userId)';
}
