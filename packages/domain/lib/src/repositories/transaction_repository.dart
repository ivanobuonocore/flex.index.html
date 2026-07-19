import 'package:pip_shared/pip_shared.dart';

import '../entities/transaction.dart';
import '../enums.dart';

/// Confine verso la persistenza delle Transazioni, implementato nel layer
/// `data` di ogni app (Dependency Inversion — Engineering Constitution,
/// Articolo 4).
abstract interface class TransactionRepository {
  /// Transazioni (pending + confirmed, non eliminate) del Workspace
  /// [workspaceId], ordinate per data.
  Stream<List<Transaction>> watchTransactions(String workspaceId);

  /// Transazione manuale: nasce sempre `confirmed`, mai `createdByAi`, senza
  /// [Transaction.chatId] — a differenza di quelle estratte dalla Chat.
  Future<Result<Transaction>> createTransaction({
    required String workspaceId,
    required TransactionType type,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
  });

  Future<Result<Transaction>> updateTransaction(Transaction transaction);

  /// `pending` -> `confirmed` (AI Constitution, Principio 1: conferma
  /// esplicita dell'utente prima che la transazione contribuisca al saldo).
  Future<Result<Transaction>> confirmTransaction(String transactionId);

  /// Soft delete. Usato sia per "scarta" (transazione `pending` suggerita
  /// dall'AI) sia per "elimina" (transazione `confirmed`) — stessa
  /// operazione, etichetta diversa in UI a seconda di [Transaction.status].
  Future<Result<Unit>> deleteTransaction(String transactionId);
}
