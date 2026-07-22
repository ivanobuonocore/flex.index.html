import '../enums.dart';

/// Singolo messaggio all'interno di una Chat (Domain Model, entità Message).
final class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachmentIds = const [],
    this.tokensUsed,
    this.sourceReferences = const [],
    this.pendingTransactionIds = const [],
  });

  final String id;
  final String chatId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final List<String> attachmentIds;
  final int? tokensUsed;

  /// Riferimenti a fonti (es. Document.id) usate dall'AI per generare la risposta.
  final List<String> sourceReferences;

  /// Id delle Transazioni pending create da questo messaggio (richiesta esplicita
  /// dell'utente: "azioni rapide sulle transazioni pending direttamente in chat") —
  /// permette alla Chat di mostrare Conferma/Scarta subito sotto la risposta
  /// dell'assistente, senza dover risalire al Bilancio. Sempre vuoto per un
  /// messaggio che non ha generato transazioni (compresi quelli di ruolo utente).
  final List<String> pendingTransactionIds;

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.chatId == chatId &&
      other.role == role &&
      other.content == content &&
      other.timestamp == timestamp &&
      _listEquals(other.attachmentIds, attachmentIds) &&
      other.tokensUsed == tokensUsed &&
      _listEquals(other.sourceReferences, sourceReferences) &&
      _listEquals(other.pendingTransactionIds, pendingTransactionIds);

  @override
  int get hashCode => Object.hash(
        id,
        chatId,
        role,
        content,
        timestamp,
        Object.hashAll(attachmentIds),
        tokensUsed,
        Object.hashAll(sourceReferences),
        Object.hashAll(pendingTransactionIds),
      );

  @override
  String toString() => 'Message(id: $id, chatId: $chatId, role: $role)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
