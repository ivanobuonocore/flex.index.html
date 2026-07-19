import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [MessageRepository]. `sendMessage` inserisce il
/// messaggio dell'utente direttamente (Postgres, RLS via join sulla Chat) e
/// poi invoca l'Edge Function `ai-chat` — l'unico punto in cui l'app tocca
/// un provider AI, sempre indiretto (CLAUDE.md: mai il frontend collegato
/// direttamente a un provider). La risposta dell'assistente arriva tramite
/// [watchMessages] (realtime), non dal valore di ritorno qui.
class SupabaseMessageRepository implements MessageRepository {
  SupabaseMessageRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'messages';
  static const _aiChatFunction = 'ai-chat';

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Result<Unit>> sendMessage({
    required String chatId,
    required String? workspaceId,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Result.err(ValidationFailure('Il messaggio non può essere vuoto.'));
    }

    try {
      await _client.from(_table).insert({
        'chat_id': chatId,
        'role': MessageRole.user.name,
        'content': trimmed,
      });
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile inviare il messaggio.', cause: e),
      );
    }

    try {
      final response = await _client.functions.invoke(
        _aiChatFunction,
        body: {'chatId': chatId, 'workspaceId': workspaceId},
      );
      if (response.status != 200) {
        return const Result.err(
          UnexpectedFailure('L\'assistente non è riuscito a rispondere. Riprova.'),
        );
      }
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('L\'assistente non è riuscito a rispondere. Riprova.', cause: e),
      );
    }
  }

  Message _toDomain(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      chatId: row['chat_id'] as String,
      role: _roleFromDb(row['role'] as String),
      content: row['content'] as String,
      timestamp: DateTime.parse(row['created_at'] as String),
      attachmentIds: (row['attachment_ids'] as List<dynamic>).cast<String>(),
      tokensUsed: row['tokens_used'] as int?,
      sourceReferences: (row['source_references'] as List<dynamic>).cast<String>(),
    );
  }

  MessageRole _roleFromDb(String value) => switch (value) {
        'user' => MessageRole.user,
        'ai' => MessageRole.ai,
        'system' => MessageRole.system,
        _ => throw ArgumentError('Ruolo messaggio sconosciuto: $value'),
      };
}
