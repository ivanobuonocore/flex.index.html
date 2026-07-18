import 'package:pip_shared/pip_shared.dart';

import '../entities/workspace.dart';

/// Confine verso la persistenza dei Workspace, implementato nel layer `data`
/// di ogni app. L'isolamento tra Workspace è responsabilità
/// dell'implementazione (RLS lato Supabase per l'app mobile) — Architectural
/// Principles, Principio 9.
abstract interface class WorkspaceRepository {
  /// Workspace dell'utente autenticato correntemente, ordinati per attività recente.
  Stream<List<Workspace>> watchWorkspaces();

  Future<Result<Workspace>> createWorkspace({
    required String name,
    required String icon,
    String? description,
    String? category,
    String? color,
  });

  Future<Result<Workspace>> updateWorkspace(Workspace workspace);

  /// Soft delete (Domain Model, Principio 3): il Workspace viene archiviato,
  /// non eliminato fisicamente.
  Future<Result<Unit>> archiveWorkspace(String workspaceId);
}
