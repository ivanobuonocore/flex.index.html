import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository(
      {this.createResult,
      this.confirmResult,
      this.updateResult,
      this.attachDocumentResult});

  final _controller = StreamController<List<Transaction>>.broadcast();
  Result<Transaction>? createResult;
  Result<Transaction>? confirmResult;
  Result<Transaction>? updateResult;
  Result<Transaction>? attachDocumentResult;
  Transaction? lastCreated;
  Transaction? lastUpdated;
  String? lastConfirmedId;
  String? lastDeletedId;
  TransactionCategory? lastCreatedCategory;
  List<String>? lastCreatedTags;
  String? lastAttachedTransactionId;
  String? lastAttachedDocumentId;
  bool attachDocumentCalled = false;
  Result<ReceiptExtraction?>? extractReceiptDataResult;
  String? lastExtractReceiptDocumentId;

  void emit(List<Transaction> transactions) => _controller.add(transactions);

  @override
  Stream<List<Transaction>> watchTransactions(String? workspaceId) =>
      _controller.stream;

  @override
  Future<Result<Transaction>> createTransaction({
    required String workspaceId,
    required TransactionType type,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
    TransactionCategory category = TransactionCategory.altro,
    List<String> tags = const [],
  }) async {
    lastCreatedCategory = category;
    lastCreatedTags = tags;
    final result = createResult ??
        const Result<Transaction>.err(
            ValidationFailure('Nessun risultato configurato.'));
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
        const Result<Transaction>.err(
            ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> deleteTransaction(String transactionId) async {
    lastDeletedId = transactionId;
    return const Result.ok(unit);
  }

  @override
  Future<Result<Transaction>> attachDocument({
    required String transactionId,
    required String? documentId,
  }) async {
    attachDocumentCalled = true;
    lastAttachedTransactionId = transactionId;
    lastAttachedDocumentId = documentId;
    return attachDocumentResult ??
        const Result<Transaction>.err(
            ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<ReceiptExtraction?>> extractReceiptData(
      String documentId) async {
    lastExtractReceiptDocumentId = documentId;
    return extractReceiptDataResult ?? const Result.ok(null);
  }

  void dispose() => _controller.close();
}
