import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Transazioni (entrate/uscite) di un Workspace, in tempo reale (Software
/// Architecture, "Sincronizzazione" — Realtime lato Supabase). `null` =
/// transazioni di tutti i Workspace dell'utente (schermata Bilancio globale).
final transactionsProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String?>(
  (ref, workspaceId) =>
      ref.watch(transactionRepositoryProvider).watchTransactions(workspaceId),
);

final transactionFormControllerProvider =
    AsyncNotifierProvider.autoDispose<TransactionFormController, void>(
        TransactionFormController.new);

class TransactionFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String workspaceId,
    required TransactionType type,
    required String description,
    required int amountCents,
    required DateTime occurredAt,
    TransactionCategory category = TransactionCategory.altro,
  }) async {
    state = const AsyncLoading();
    final result =
        await ref.read(transactionRepositoryProvider).createTransaction(
              workspaceId: workspaceId,
              type: type,
              description: description,
              amountCents: amountCents,
              occurredAt: occurredAt,
              category: category,
            );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> updateTransaction(Transaction transaction) async {
    state = const AsyncLoading();
    final result = await ref
        .read(transactionRepositoryProvider)
        .updateTransaction(transaction);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// `pending` -> `confirmed` (AI Constitution, Principio 1): solo da qui una
  /// transazione suggerita dall'AI inizia a contare nel saldo.
  Future<Failure?> confirm(String transactionId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(transactionRepositoryProvider)
        .confirmTransaction(transactionId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// Usato sia per "scarta" (transazione pending) sia per "elimina"
  /// (transazione confermata) — stessa operazione, label diversa in UI.
  Future<Failure?> delete(String transactionId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(transactionId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}

/// Transazioni confermate che ricadono nel mese di [now] (default: oggi).
/// Pure, testabile senza Riverpod.
List<Transaction> confirmedThisMonth(List<Transaction> transactions,
    {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return transactions
      .where((t) =>
          t.status == TransactionStatus.confirmed &&
          t.occurredAt.year == reference.year &&
          t.occurredAt.month == reference.month)
      .toList(growable: false);
}

/// Transazioni in attesa di conferma, **non** filtrate per mese: una
/// transazione pending di un mese diverso da quello corrente deve restare
/// visibile finché l'utente non la conferma o la scarta.
List<Transaction> pendingTransactions(List<Transaction> transactions) {
  return transactions
      .where((t) => t.status == TransactionStatus.pending)
      .toList(growable: false);
}

/// Somma degli importi (in centesimi) delle entrate indicate.
int totalIncomeCents(Iterable<Transaction> transactions) {
  return transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amountCents);
}

/// Somma degli importi (in centesimi) delle uscite indicate.
int totalExpenseCents(Iterable<Transaction> transactions) {
  return transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amountCents);
}

/// Saldo (entrate − uscite) delle transazioni indicate.
int balanceCents(Iterable<Transaction> transactions) {
  return totalIncomeCents(transactions) - totalExpenseCents(transactions);
}
