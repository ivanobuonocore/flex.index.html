import '../enums.dart';

/// Modello per una Transazione (spesa o entrata) che si ripete nel tempo
/// (Domain Model — richiesta esplicita dell'utente: "spese ricorrenti
/// automatiche", es. un canone mensile). Scritto solo dall'AI Engine (tool
/// `create_recurring_transaction`), come il livello Globale della Memoria —
/// nessun metodo di creazione manuale nel repository.
///
/// A ogni occorrenza dovuta, l'Edge Function `create-due-recurring-transactions`
/// (invocata da un cron job Postgres) inserisce UNA nuova [Transaction] "in
/// attesa di conferma" — non l'intera serie in anticipo come per i Promemoria
/// ricorrenti: un dato finanziario futuro elencato tutto insieme oggi
/// confonderebbe la sezione "in attesa di conferma" del Bilancio.
final class RecurringTransactionTemplate {
  const RecurringTransactionTemplate({
    required this.id,
    required this.workspaceId,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.category,
    required this.frequency,
    required this.nextOccurrenceAt,
    required this.anchorDay,
    required this.createdAt,
  });

  final String id;
  final String workspaceId;
  final TransactionType type;
  final String description;
  final int amountCents;
  final TransactionCategory category;
  final RecurrenceFrequency frequency;

  /// Prossima data in cui va generata una nuova [Transaction] pending.
  /// Avanzata dall'Edge Function dopo ogni generazione.
  final DateTime nextOccurrenceAt;

  /// Giorno del mese "vero" della ricorrenza (1-31), fissato alla creazione:
  /// evita che un mese corto faccia scivolare la scadenza in modo permanente
  /// (stesso bug già corretto per i Promemoria ricorrenti). Non rilevante per
  /// [RecurrenceFrequency.weekly].
  final int anchorDay;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is RecurringTransactionTemplate &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.type == type &&
      other.description == description &&
      other.amountCents == amountCents &&
      other.category == category &&
      other.frequency == frequency &&
      other.nextOccurrenceAt == nextOccurrenceAt &&
      other.anchorDay == anchorDay &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        type,
        description,
        amountCents,
        category,
        frequency,
        nextOccurrenceAt,
        anchorDay,
        createdAt,
      );

  @override
  String toString() =>
      'RecurringTransactionTemplate(id: $id, description: $description, frequency: $frequency)';
}
