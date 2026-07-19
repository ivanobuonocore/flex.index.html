import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository({this.createResult, this.confirmResult, this.updateResult});

  final _controller = StreamController<List<Transaction>>.broadcast();
  Result<Transaction>? createResult;
  Result<Transaction>? confirmResult;
  Result<Transaction>? updateResult;
  Transaction? lastCreated;
  Transaction? lastUpdated;
  String? lastConfirmedId;
  String? lastDeletedId;

  void emit(List<Transaction> transactions) => _controller.add(transactions);

  @override
  Stream<List<Transaction>> watchTransactions(String workspaceId) => _controller.stream;

  @override
  Future<Result<Transaction>> createTransaction({
    required String workspaceId,
    required TransactionType type,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
  }) async {
    final result = createResult ??
        const Result<Transaction>.err(ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<Transaction>).value;
    }
    return result;
  }

  @override
  Future<Result<Transaction>> updateTransaction(Transaction transaction) async {
    lastUpdated = transaction;
    return updateResult ?? Result.ok(transaction);
  }

  @override
  Future<Result<Transaction>> confirmTransaction(String transactionId) async {
    lastConfirmedId = transactionId;
    return confirmResult ??
        const Result<Transaction>.err(ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> deleteTransaction(String transactionId) async {
    lastDeletedId = transactionId;
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
