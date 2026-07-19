import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Spese di un Workspace, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final expensesProvider = StreamProvider.autoDispose.family<List<Expense>, String>(
  (ref, workspaceId) => ref.watch(expenseRepositoryProvider).watchExpenses(workspaceId),
);

final expenseFormControllerProvider =
    AsyncNotifierProvider.autoDispose<ExpenseFormController, void>(
        ExpenseFormController.new);

class ExpenseFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String workspaceId,
    required String description,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(expenseRepositoryProvider).createExpense(
          workspaceId: workspaceId,
          description: description,
          amountCents: amountCents,
          occurredAt: occurredAt,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> updateExpense(Expense expense) async {
    state = const AsyncLoading();
    final result = await ref.read(expenseRepositoryProvider).updateExpense(expense);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// `pending` -> `confirmed` (AI Constitution, Principio 1): solo da qui una
  /// spesa suggerita dall'AI inizia a contare nei totali.
  Future<Failure?> confirm(String expenseId) async {
    state = const AsyncLoading();
    final result = await ref.read(expenseRepositoryProvider).confirmExpense(expenseId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// Usato sia per "scarta" (spesa pending) sia per "elimina" (spesa
  /// confermata) — stessa operazione, label diversa in UI.
  Future<Failure?> delete(String expenseId) async {
    state = const AsyncLoading();
    final result = await ref.read(expenseRepositoryProvider).deleteExpense(expenseId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}

/// Spese confermate che ricadono nel mese di [now] (default: oggi). Pure,
/// testabile senza Riverpod.
List<Expense> confirmedThisMonth(List<Expense> expenses, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return expenses
      .where((e) =>
          e.status == ExpenseStatus.confirmed &&
          e.occurredAt.year == reference.year &&
          e.occurredAt.month == reference.month)
      .toList(growable: false);
}

/// Spese in attesa di conferma, **non** filtrate per mese: una spesa pending
/// di un mese diverso da quello corrente deve restare visibile finché
/// l'utente non la conferma o la scarta.
List<Expense> pendingExpenses(List<Expense> expenses) {
  return expenses.where((e) => e.status == ExpenseStatus.pending).toList(growable: false);
}

/// Somma degli importi (in centesimi) delle spese indicate.
int totalCents(Iterable<Expense> expenses) {
  return expenses.fold(0, (sum, e) => sum + e.amountCents);
}
