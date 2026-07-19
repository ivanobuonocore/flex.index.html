import 'package:pip_shared/pip_shared.dart';

import '../entities/expense.dart';

/// Confine verso la persistenza delle Spese, implementato nel layer `data` di
/// ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
abstract interface class ExpenseRepository {
  /// Spese (pending + confirmed, non eliminate) del Workspace [workspaceId],
  /// ordinate per data spesa.
  Stream<List<Expense>> watchExpenses(String workspaceId);

  /// Spesa manuale: nasce sempre `confirmed`, mai `createdByAi`, senza
  /// [Expense.chatId] — a differenza di quelle estratte dalla Chat.
  Future<Result<Expense>> createExpense({
    required String workspaceId,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
  });

  Future<Result<Expense>> updateExpense(Expense expense);

  /// `pending` -> `confirmed` (AI Constitution, Principio 1: conferma
  /// esplicita dell'utente prima che la spesa contribuisca a un totale).
  Future<Result<Expense>> confirmExpense(String expenseId);

  /// Soft delete. Usato sia per "scarta" (spesa `pending` suggerita
  /// dall'AI) sia per "elimina" (spesa `confirmed`) — stessa operazione,
  /// etichetta diversa in UI a seconda di [Expense.status].
  Future<Result<Unit>> deleteExpense(String expenseId);
}
