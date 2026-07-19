import 'package:pip_shared/pip_shared.dart';

import '../entities/chat.dart';

/// Confine verso la persistenza delle Chat, implementato nel layer `data` di
/// ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
abstract interface class ChatRepository {
  /// Chat dell'utente autenticato, ordinate per ultima attività.
  /// [workspaceId] null = tutte le Chat (tab globale, docs/product/06,
  /// "Chat" — "può essere privata, collegata a un Workspace").
  Stream<List<Chat>> watchChats(String? workspaceId);

  Future<Result<Chat>> createChat({
    required String? workspaceId,
    required String title,
  });

  /// Soft delete (Domain Model, "Principi del modello").
  Future<Result<Unit>> archiveChat(String chatId);
}
