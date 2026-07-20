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
  });

  final String id;
  final String workspaceId;

  /// Valorizzato solo per le transazioni estratte dall'AI Engine da un
  /// messaggio di Chat (traccia la fonte, AI Constitution, Principio 3 —
  /// Trasparenza).
  final String? chatId;

  final TransactionType type;
  final String description;

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

  Transaction copyWith({
    String? description,
    int? amountCents,
    DateTime? occurredAt,
    TransactionStatus? status,
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
      other.deletedAt == deletedAt;

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
      );

  @override
  String toString() =>
      'Transaction(id: $id, type: $type, description: $description, amountCents: $amountCents, status: $status)';
}
