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
        .map((rows) => rows.map(parseMessageRow).toList(growable: false));
  }

  @override
  Future<Result<Unit>> sendMessage({
    required String chatId,
    required String? workspaceId,
    required String content,
    List<String> attachmentIds = const [],
    String? remindersWorkspaceId,
    String? tasksWorkspaceId,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const Result.err(
          ValidationFailure('Il messaggio non può essere vuoto.'));
    }

    try {
      await _client.from(_table).insert({
        'chat_id': chatId,
        'role': MessageRole.user.name,
        'content': trimmed,
        'attachment_ids': attachmentIds,
      });
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile inviare il messaggio.',
            cause: e),
      );
    }

    try {
      final response = await _client.functions.invoke(
        _aiChatFunction,
        body: {
          'chatId': chatId,
          'workspaceId': workspaceId,
          'remindersWorkspaceId': remindersWorkspaceId,
          'tasksWorkspaceId': tasksWorkspaceId,
        },
      );
      if (response.status != 200) {
        return const Result.err(
          UnexpectedFailure(
              'L\'assistente non è riuscito a rispondere. Riprova.'),
        );
      }
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('L\'assistente non è riuscito a rispondere. Riprova.',
            cause: e),
      );
    }
  }
}

/// Converte una riga di `messages` in un [Message] — funzione pura (non un
/// metodo privato) perché testabile senza dover mockare il client Supabase,
/// stesso motivo di `parseReceiptExtractionResponse` in
/// `supabase_transaction_repository.dart`.
///
/// Le tre colonne array (`attachment_ids`/`source_references`/
/// `pending_transaction_ids`) sono lette con un cast tollerante a `null`
/// invece che diretto: una colonna aggiunta con una migrazione additiva più
/// recente (`pending_transaction_ids`, slice "Conferma/Scarta inline") arriva
/// `null` — non assente dalla riga, `null` come valore — quando quella
/// migrazione non è ancora stata applicata al progetto Supabase reale (mai
/// automatico, vedi `apps/mobile/README.md`), e un cast diretto la faceva
/// esplodere dentro il `.map()` dello stream realtime, con l'intera Chat che
/// mostrava "Non è stato possibile caricare i messaggi." per un problema
/// operativo (migrazione non pushata), non un errore di rete o RLS reale —
/// stesso tipo di gap già capitato con la colonna `category` di Transazione.
Message parseMessageRow(Map<String, dynamic> row) {
  return Message(
    id: row['id'] as String,
    chatId: row['chat_id'] as String,
    role: _roleFromDb(row['role'] as String),
    content: row['content'] as String,
    timestamp: DateTime.parse(row['created_at'] as String),
    attachmentIds:
        (row['attachment_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
    tokensUsed: row['tokens_used'] as int?,
    sourceReferences:
        (row['source_references'] as List<dynamic>?)?.cast<String>() ??
            const [],
    pendingTransactionIds:
        (row['pending_transaction_ids'] as List<dynamic>?)?.cast<String>() ??
            const [],
  );
}

MessageRole _roleFromDb(String value) => switch (value) {
      'user' => MessageRole.user,
      'ai' => MessageRole.ai,
      'system' => MessageRole.system,
      _ => throw ArgumentError('Ruolo messaggio sconosciuto: $value'),
    };
