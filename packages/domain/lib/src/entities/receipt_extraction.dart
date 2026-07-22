import '../enums.dart';

/// Risultato della lettura automatica di uno scontrino/ricevuta allegato a una
/// Transazione (OCR via AI Engine — integrazione richiesta esplicitamente),
/// da usare per precompilare il form: l'utente resta libero di correggere
/// ogni campo prima di salvare ("l'AI suggerisce, l'utente decide", stesso
/// principio già applicato al resto dell'AI Engine).
final class ReceiptExtraction {
  const ReceiptExtraction({
    required this.type,
    required this.description,
    required this.amountCents,
    required this.occurredAt,
    required this.category,
  });

  final TransactionType type;
  final String description;
  final int amountCents;
  final DateTime occurredAt;
  final TransactionCategory category;

  @override
  bool operator ==(Object other) =>
      other is ReceiptExtraction &&
      other.type == type &&
      other.description == description &&
      other.amountCents == amountCents &&
      other.occurredAt == occurredAt &&
      other.category == category;

  @override
  int get hashCode =>
      Object.hash(type, description, amountCents, occurredAt, category);

  @override
  String toString() =>
      'ReceiptExtraction(description: $description, amountCents: $amountCents, category: $category)';
}
