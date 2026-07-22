import '../enums.dart';

/// Codice d'invito per unirsi a un Bilancio condiviso (Fase 3, "Bilancio
/// condiviso"). Un invito è a uso singolo: [usedAt]/[usedBy] valorizzati dopo
/// il primo redeem, non più utilizzabile da quel momento (né dopo
/// [expiresAt]). Niente infrastruttura email/deep-link in questa slice: il
/// [code] va condiviso manualmente (messaggio, chiamata, ecc.) e inserito
/// dall'altro utente nell'app.
final class WorkspaceInvite {
  const WorkspaceInvite({
    required this.id,
    required this.workspaceId,
    required this.code,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.role = WorkspaceRole.editor,
    this.usedAt,
    this.usedBy,
  });

  final String id;
  final String workspaceId;
  final String code;

  /// [User.id] del proprietario del Workspace che ha generato l'invito.
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Ruolo che verrà assegnato in [WorkspaceMember.role] al momento del
  /// redeem (integrazione richiesta esplicitamente: "permessi granulari") —
  /// deciso dal proprietario qui, mai da chi redime l'invito.
  final WorkspaceRole role;
  final DateTime? usedAt;
  final String? usedBy;

  bool get isUsed => usedAt != null;
  bool isExpired({DateTime? now}) => (now ?? DateTime.now()).isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      other is WorkspaceInvite &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.code == code &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt &&
      other.expiresAt == expiresAt &&
      other.role == role &&
      other.usedAt == usedAt &&
      other.usedBy == usedBy;

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        code,
        createdBy,
        createdAt,
        expiresAt,
        role,
        usedAt,
        usedBy,
      );

  @override
  String toString() => 'WorkspaceInvite(id: $id, workspaceId: $workspaceId, '
      'code: $code, isUsed: $isUsed)';
}
