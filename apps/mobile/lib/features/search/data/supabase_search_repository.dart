import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [SearchRepository] su Supabase Postgres. Delega tutto
/// il lavoro cross-tabella alla funzione `search_workspace_content`
/// (`infrastructure/supabase/migrations`), `SECURITY INVOKER`: l'isolamento
/// tra Workspace è garantito dalle RLS delle tabelle sottostanti, non da
/// codice qui — verificato manualmente lato migrazione.
class SupabaseSearchRepository implements SearchRepository {
  SupabaseSearchRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<Result<List<SearchResult>>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Result.ok([]);

    try {
      final rows = await _client.rpc(
        'search_workspace_content',
        params: {'query': trimmed},
      ) as List<dynamic>;
      final results = rows
          .cast<Map<String, dynamic>>()
          .map(_toDomain)
          .toList(growable: false);
      return Result.ok(results);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile completare la ricerca.',
            cause: e),
      );
    }
  }

  SearchResult _toDomain(Map<String, dynamic> row) {
    return SearchResult(
      type: _typeFromDb(row['result_type'] as String),
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      title: row['title'] as String,
      snippet: row['snippet'] as String?,
    );
  }

  SearchResultType _typeFromDb(String value) => switch (value) {
        'workspace' => SearchResultType.workspace,
        'note' => SearchResultType.note,
        'task' => SearchResultType.task,
        'document' => SearchResultType.document,
        _ => throw ArgumentError('Tipo di risultato sconosciuto: $value'),
      };
}
