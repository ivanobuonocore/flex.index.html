import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [WorkspaceSharingRepository] su Supabase Postgres
/// (`infrastructure/supabase/migrations/20260721160000_workspace_sharing.sql`).
/// L'isolamento è garantito interamente dalle policy RLS aggiuntive di
/// `workspaces`/`transactions` e dalla funzione `redeem_workspace_invite`
/// (SECURITY DEFINER) — nessun filtro `owner_id`/membro qui, coerente con lo
/// stesso principio già seguito da `SupabaseWorkspaceRepository`.
class SupabaseWorkspaceSharingRepository implements WorkspaceSharingRepository {
  SupabaseWorkspaceSharingRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _workspacesTable = 'workspaces';
  static const _membersTable = 'workspace_members';
  static const _invitesTable = 'workspace_invites';

  @override
  Stream<List<Workspace>> watchSharedBalances() {
    return _client
        .from(_workspacesTable)
        .stream(primaryKey: ['id'])
        .eq('category', sharedBalanceCategory)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_workspaceFromDb)
              .toList(growable: false),
        );
  }

  @override
  Stream<List<WorkspaceMember>> watchMembers(String workspaceId) {
    return _client
        .from(_membersTable)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('joined_at', ascending: true)
        .map(
          (rows) => rows.map(_memberFromDb).toList(growable: false),
        );
  }

  @override
  Future<Result<WorkspaceInvite>> createInvite(String workspaceId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(
          AuthFailure('Devi accedere per creare un invito.'));
    }

    try {
      final row = await _client
          .from(_invitesTable)
          .insert({'workspace_id': workspaceId, 'created_by': userId})
          .select()
          .single();
      return Result.ok(_inviteFromDb(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile creare l\'invito.', cause: e),
      );
    }
  }

  @override
  Future<Result<Workspace>> redeemInvite(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      return const Result.err(
          ValidationFailure('Inserisci un codice d\'invito.'));
    }

    try {
      final workspaceId = await _client.rpc(
        'redeem_workspace_invite',
        params: {'p_code': trimmed.toUpperCase()},
      ) as String;
      final row = await _client
          .from(_workspacesTable)
          .select()
          .eq('id', workspaceId)
          .single();
      return Result.ok(_workspaceFromDb(row));
    } on supabase.PostgrestException catch (e) {
      // I messaggi di `redeem_workspace_invite` (codice non valido/scaduto/
      // già usato/proprio) sono già scritti per l'utente finale (RAISE
      // EXCEPTION nella funzione SQL) — mostrarli direttamente evita di
      // doverli duplicare qui in una traduzione parallela.
      return Result.err(ValidationFailure(e.message));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile unirsi al Bilancio condiviso.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> removeMember({
    required String workspaceId,
    required String userId,
  }) async {
    try {
      await _client
          .from(_membersTable)
          .delete()
          .eq('workspace_id', workspaceId)
          .eq('user_id', userId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile rimuovere il membro.',
            cause: e),
      );
    }
  }

  Workspace _workspaceFromDb(Map<String, dynamic> row) {
    return Workspace(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      icon: row['icon'] as String,
      category: row['category'] as String?,
      status: WorkspaceStatus.values.byName(row['status'] as String),
      color: row['color'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  WorkspaceMember _memberFromDb(Map<String, dynamic> row) {
    return WorkspaceMember(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      userId: row['user_id'] as String,
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }

  WorkspaceInvite _inviteFromDb(Map<String, dynamic> row) {
    return WorkspaceInvite(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      code: row['code'] as String,
      createdBy: row['created_by'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      usedAt: row['used_at'] == null
          ? null
          : DateTime.parse(row['used_at'] as String),
      usedBy: row['used_by'] as String?,
    );
  }
}
