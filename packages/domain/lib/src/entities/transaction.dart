import '../enums.dart';

/// Entrata o uscita personale registrata in un Workspace (Domain Model —
/// entità aggiunta oltre allo scaffold originale, vedi
/// docs/database/README.md). Le transazioni create manualmente nascono già
/// `confirmed`; quelle estratte dall'AI Engine dalla Chat nascono `pending` e
/// diventano `confirmed` solo su conferma esplicita dell'utente (AI
/// Constitution, Principio 1). Il bilancio di un Workspace è la somma delle
/// transazioni `confirmed`, con segno dato da [type].
final class Transaction {
  const Transaction({
    required this.id,
    required this.workspaceId,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.occurredAt,
    required this.status,
    required this.createdAt,
    this.currency = 'EUR',
    this.chatId,
    this.createdByAi = false,
    this.deletedAt,
    this.category = TransactionCategory.altro,
    this.documentId,
    this.tags = const [],
  });

  final String id;
  final String workspaceId;

  /// Valorizzato solo per le transazioni estratte dall'AI Engine da un
  /// messaggio di Chat (traccia la fonte, AI Constitution, Principio 3 —
  /// Trasparenza).
  final String? chatId;

  /// Scontrino/ricevuta allegata (richiesta esplicita dell'utente: "scontrino
  /// allegato alla Transazione") — un [Document] persistente e consultabile
  /// dopo, non solo la foto temporanea che l'AI legge per estrarre
  /// l'importo. Gestito solo tramite [TransactionRepository.attachDocument],
  /// non tramite [copyWith] (nessun modo pulito di rappresentare "rimuovi
  /// l'allegato" in un copyWith che usa `?? this.x`).
  final String? documentId;

  final TransactionType type;
  final String description;

  /// Fase 3, slice 7C ("Bilancio con categorie"). Default [TransactionCategory.altro]:
  /// mai `null`, così ogni transazione — anche quelle create prima di questa
  /// slice — ha sempre una categoria da mostrare.
  final TransactionCategory category;

  /// Importo in centesimi, sempre positivo (mai un double, per evitare
  /// errori di somma): il segno nel bilancio lo decide [type].
  final int amountCents;
  final String currency;
  final DateTime occurredAt;
  final TransactionStatus status;
  final bool createdByAi;
  final DateTime createdAt;

  /// Soft delete (Domain Model, "Principi del modello").
  final DateTime? deletedAt;

  /// Tag liberi assegnati manualmente dall'utente (integrazione richiesta
  /// esplicitamente) — stesso pattern di [Note.tags]: mai popolati dall'AI
  /// Engine, `extract_transactions` non li tocca.
  final List<String> tags;

  Transaction copyWith({
    String? description,
    int? amountCents,
    DateTime? occurredAt,
    TransactionStatus? status,
    TransactionCategory? category,
    List<String>? tags,
  }) {
    return Transaction(
      id: id,
      workspaceId: workspaceId,
      chatId: chatId,
      type: type,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      currency: currency,
      occurredAt: occurredAt ?? this.occurredAt,
      status: status ?? this.status,
      createdByAi: createdByAi,
      createdAt: createdAt,
      deletedAt: deletedAt,
      category: category ?? this.category,
      documentId: documentId,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.chatId == chatId &&
      other.type == type &&
      other.description == description &&
      other.amountCents == amountCents &&
      other.currency == currency &&
      other.occurredAt == occurredAt &&
      other.status == status &&
      other.createdByAi == createdByAi &&
      other.createdAt == createdAt &&
      other.deletedAt == deletedAt &&
      other.category == category &&
      other.documentId == documentId &&
      _listEquals(other.tags, tags);

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        chatId,
        type,
        description,
        amountCents,
        currency,
        occurredAt,
        status,
        createdByAi,
        createdAt,
        deletedAt,
        category,
        documentId,
        Object.hashAll(tags),
      );

  @override
  String toString() =>
      'Transaction(id: $id, type: $type, description: $description, amountCents: $amountCents, status: $status)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
