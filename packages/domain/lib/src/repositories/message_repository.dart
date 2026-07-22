import 'package:pip_shared/pip_shared.dart';

import '../entities/message.dart';

/// Confine verso la persistenza dei Message e verso l'AI Engine (Edge
/// Function `ai-chat`), implementato nel layer `data` di ogni app.
/// L'app non chiama mai direttamente un provider AI (CLAUDE.md): ogni
/// implementazione di [sendMessage] passa dall'AI Engine.
abstract interface class MessageRepository {
  /// Messaggi della Chat [chatId], in ordine cronologico.
  Stream<List<Message>> watchMessages(String chatId);

  /// Inserisce il messaggio dell'utente e avvia il turno dell'AI. La
  /// risposta dell'assistente arriva tramite [watchMessages] (realtime), non
  /// come valore di ritorno qui — l'implementazione nasconde al chiamante
  /// che sono due passi (insert + invocazione dell'AI Engine).
  /// [attachmentIds]: id di [Document] caricati come foto allegate a questo
  /// messaggio (docs/database/README.md, sezione Documenti) — vuoto per un
  /// messaggio di solo testo.
  Future<Result<Unit>> sendMessage({
    required String chatId,
    required String? workspaceId,
    required String content,
    List<String> attachmentIds = const [],
    String? remindersWorkspaceId,
    String? tasksWorkspaceId,
  });
}
