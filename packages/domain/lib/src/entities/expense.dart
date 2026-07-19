import '../enums.dart';

/// Spesa personale registrata in un Workspace (Domain Model — entità aggiunta
/// oltre allo scaffold originale, vedi docs/database/README.md). Le spese
/// create manualmente nascono già `confirmed`; quelle estratte dall'AI Engine
/// dalla Chat nascono `pending` e diventano `confirmed` solo su conferma
/// esplicita dell'utente (AI Constitution, Principio 1).
final class Expense {
  const Expense({
    required this.id,
    required this.workspaceId,
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

  /// Valorizzato solo per le spese estratte dall'AI Engine da un messaggio
  /// di Chat (traccia la fonte, AI Constitution, Principio 3 — Trasparenza).
  final String? chatId;

  final String description;

  /// Importo in centesimi (mai un double, per evitare errori di somma).
  final int amountCents;
  final String currency;
  final DateTime occurredAt;
  final ExpenseStatus status;
  final bool createdByAi;
  final DateTime createdAt;

  /// Soft delete (Domain Model, "Principi del modello").
  final DateTime? deletedAt;

  Expense copyWith({
    String? description,
    int? amountCents,
    DateTime? occurredAt,
    ExpenseStatus? status,
  }) {
    return Expense(
      id: id,
      workspaceId: workspaceId,
      chatId: chatId,
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
      other is Expense &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.chatId == chatId &&
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
      'Expense(id: $id, description: $description, amountCents: $amountCents, status: $status)';
}
