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
    return Memory(
      id: row['id'] as String,
      content: row['content'] as String,
      level: MemoryLevel.global,
      origin: (row['origin'] as String) == 'ai'
          ? MemoryOrigin.ai
          : MemoryOrigin.user,
      userId: row['user_id'] as String?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
