import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [WorkspaceRepository] su Supabase Postgres.
///
/// L'isolamento tra utenti è garantito dalle policy RLS della tabella
/// `workspaces` (`infrastructure/supabase/migrations`), non dal filtro
/// applicativo qui sotto: quest'ultimo esiste solo per costruire la query,
/// non come unico meccanismo di sicurezza (Architectural Principles,
/// Principio 9).
class SupabaseWorkspaceRepository implements WorkspaceRepository {
  SupabaseWorkspaceRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'workspaces';

  @override
  Stream<List<Workspace>> watchWorkspaces() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value(const []);

    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Workspace>> createWorkspace({
    required String name,
    required String icon,
    String? description,
    String? category,
    String? color,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(
          AuthFailure('Devi accedere per creare un Workspace.'));
    }
    if (name.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('Il nome del Workspace è obbligatorio.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'owner_id': userId,
            'name': name.trim(),
            'description': description,
            'icon': icon,
            'category': category,
            'color': color,
            'status': WorkspaceStatus.active.name,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile creare il Workspace.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Workspace>> updateWorkspace(Workspace workspace) async {
    try {
      final row = await _client
          .from(_table)
          .update({
            'name': workspace.name,
            'description': workspace.description,
            'icon': workspace.icon,
            'category': workspace.category,
            'color': workspace.color,
            'status': workspace.status.name,
          })
          .eq('id', workspace.id)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aggiornare il Workspace.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> archiveWorkspace(String workspaceId) async {
    try {
      await _client.from(_table).update({
        'status': WorkspaceStatus.archived.name,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', workspaceId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile archiviare il Workspace.',
            cause: e),
      );
    }
  }

  Workspace _toDomain(Map<String, dynamic> row) {
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
}
