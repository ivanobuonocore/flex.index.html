import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [MemoryRepository] su Supabase Postgres. Prima slice
/// minima: solo il livello globale — l'isolamento tra utenti è garantito
/// dalle policy RLS di `memories` (`infrastructure/supabase/migrations`), non
/// da un filtro applicativo qui sotto.
class SupabaseMemoryRepository implements MemoryRepository {
  SupabaseMemoryRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'memories';

  @override
  Stream<List<Memory>> watchGlobalMemories() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('level', 'global')
        .order('updated_at', ascending: false)
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Stream<List<Memory>> watchWorkspaceMemories(String workspaceId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('updated_at', ascending: false)
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Result<Memory>> createWorkspaceMemory({
    required String workspaceId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Result.err(
          ValidationFailure('Il contenuto della memoria è obbligatorio.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'content': trimmed,
            'level': 'workspace',
            'origin': 'user',
            'workspace_id': workspaceId,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile salvare la memoria.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteMemory(String memoryId) async {
    try {
      await _client.from(_table).delete().eq('id', memoryId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare la memoria.',
            cause: e),
      );
    }
  }

  Memory _toDomain(Map<String, dynamic> row) {
    final level = (row['level'] as String) == 'workspace'
        ? MemoryLevel.workspace
        : MemoryLevel.global;
    return Memory(
      id: row['id'] as String,
      content: row['content'] as String,
      level: level,
      origin: (row['origin'] as String) == 'ai'
          ? MemoryOrigin.ai
          : MemoryOrigin.user,
      userId: row['user_id'] as String?,
      workspaceId: row['workspace_id'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
