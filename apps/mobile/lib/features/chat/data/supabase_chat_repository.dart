import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Modello inviato di default per le nuove Chat. Coerente con il system
/// prompt costruito dalla Edge Function `ai-chat`
/// (`infrastructure/supabase/functions/ai-chat`).
const kDefaultAiModel = 'claude-sonnet-5';

/// Implementazione di [ChatRepository] su Supabase Postgres. L'isolamento tra
/// utenti è garantito dalle policy RLS della tabella `chats`
/// (`infrastructure/supabase/migrations`), non dal filtro applicativo qui
/// sotto (stesso principio di [SupabaseWorkspaceRepository]): `.stream()`
/// supporta un solo filtro `eq`, quindi qui si usa solo per lo scoping al
/// Workspace quando richiesto — l'isolamento per utente resta compito di RLS.
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'chats';

  @override
  Stream<List<Chat>> watchChats(String? workspaceId) {
    if (_client.auth.currentUser?.id == null) return Stream.value(const []);

    final query = _client.from(_table).stream(primaryKey: ['id']);
    final scoped =
        workspaceId == null ? query : query.eq('workspace_id', workspaceId);

    return scoped
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Result<Chat>> createChat({
    required String? workspaceId,
    required String title,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(
          AuthFailure('Devi accedere per creare una chat.'));
    }
    if (title.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('Il titolo della chat è obbligatorio.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'owner_id': userId,
            'workspace_id': workspaceId,
            'title': title.trim(),
            'ai_model': kDefaultAiModel,
            'status': ChatStatus.active.name,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
          UnexpectedFailure('Non è stato possibile creare la chat.', cause: e));
    }
  }

  @override
  Future<Result<Unit>> archiveChat(String chatId) async {
    try {
      await _client
          .from(_table)
          .update({'status': ChatStatus.archived.name}).eq('id', chatId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile archiviare la chat.',
            cause: e),
      );
    }
  }

  Chat _toDomain(Map<String, dynamic> row) {
    return Chat(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      workspaceId: row['workspace_id'] as String?,
      title: row['title'] as String,
      aiModel: row['ai_model'] as String,
      status: ChatStatus.values.byName(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      lastMessageAt: row['last_message_at'] != null
          ? DateTime.parse(row['last_message_at'] as String)
          : null,
    );
  }
}
