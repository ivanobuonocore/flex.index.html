import 'package:pip_shared/pip_shared.dart';

import '../entities/workspace.dart';
import '../entities/workspace_invite.dart';
import '../entities/workspace_member.dart';
import '../enums.dart';

/// Confine verso la persistenza della condivisione di un Workspace (Fase 3,
/// "Bilancio condiviso"), implementato nel layer `data` di ogni app.
/// Interfaccia separata da [WorkspaceRepository] (Separation of Concerns): la
/// maggior parte dei Workspace non viene mai condivisa, e questo evita di
/// obbligare ogni implementazione/fake di [WorkspaceRepository] a conoscere
/// la condivisione.
abstract interface class WorkspaceSharingRepository {
  /// Bilanci condivisi dell'utente autenticato, posseduti o di cui è membro
  /// (`Workspace.category == sharedBalanceCategory`), in tempo reale. Non
  /// filtra per `owner_id` lato applicazione: l'isolamento/visibilità è
  /// interamente demandato alla RLS di `workspaces` (proprietario o membro).
  Stream<List<Workspace>> watchSharedBalances();

  /// Membri (diversi dal proprietario) di [workspaceId], in tempo reale.
  /// Significativo solo per il proprietario: un membro non gestisce gli
  /// altri membri.
  Stream<List<WorkspaceMember>> watchMembers(String workspaceId);

  /// Genera un nuovo codice d'invito per [workspaceId], con il ruolo che
  /// verrà assegnato al momento del redeem (integrazione richiesta
  /// esplicitamente: "permessi granulari" — default [WorkspaceRole.editor]
  /// per non cambiare il comportamento di default). Solo il proprietario del
  /// Workspace può generarlo (verificato via RLS).
  Future<Result<WorkspaceInvite>> createInvite(
    String workspaceId, {
    WorkspaceRole role = WorkspaceRole.editor,
  });

  /// Unisce l'utente autenticato al Workspace associato a [code], con il
  /// ruolo portato dall'invito. Fallisce se il codice non esiste, è scaduto,
  /// è già stato usato, o se l'utente prova a unirsi a un Workspace che ha
  /// creato lui stesso.
  Future<Result<Workspace>> redeemInvite(String code);

  /// Rimuove [userId] dai membri di [workspaceId] (solo il proprietario può
  /// farlo): da quel momento quell'utente perde ogni accesso a Transazioni,
  /// Note e Attività del Workspace.
  Future<Result<Unit>> removeMember({
    required String workspaceId,
    required String userId,
  });

  /// Cambia il ruolo di [userId] in [workspaceId] (solo il proprietario può
  /// farlo, verificato via RLS — un membro non può auto-assegnarsi
  /// `editor`).
  Future<Result<Unit>> updateMemberRole({
    required String workspaceId,
    required String userId,
    required WorkspaceRole role,
  });
}
