import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [NoteRepository] su Supabase Postgres. L'isolamento tra
/// Workspace è garantito dalle policy RLS di `notes`
/// (`infrastructure/supabase/migrations`), che verificano il Workspace
/// referenziato — non da un filtro applicativo qui sotto.
class SupabaseNoteRepository implements NoteRepository {
  SupabaseNoteRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'notes';

  @override
  Stream<List<Note>> watchNotes(String workspaceId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('updated_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Note>> createNote({
    required String workspaceId,
    required String title,
    String content = '',
    List<String> tags = const [],
  }) async {
    if (title.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('Il titolo della nota è obbligatorio.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'workspace_id': workspaceId,
            'title': title.trim(),
            'content': content,
            'tags': tags,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
          UnexpectedFailure('Non è stato possibile creare la nota.', cause: e));
    }
  }

  @override
  Future<Result<Note>> updateNote(Note note) async {
    try {
      final row = await _client
          .from(_table)
          .update({
            'title': note.title,
            'content': note.content,
            'tags': note.tags,
            'updated_at': note.updatedAt.toIso8601String(),
          })
          .eq('id', note.id)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aggiornare la nota.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteNote(String noteId) async {
    try {
      await _client.from(_table).update(
          {'deleted_at': DateTime.now().toIso8601String()}).eq('id', noteId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare la nota.', cause: e),
      );
    }
  }

  Note _toDomain(Map<String, dynamic> row) {
    return Note(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      tags: (row['tags'] as List<dynamic>).cast<String>(),
      createdByAi: row['created_by_ai'] as bool,
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}
