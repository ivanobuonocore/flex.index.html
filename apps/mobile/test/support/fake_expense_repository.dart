import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository({this.createResult, this.confirmResult, this.updateResult});

  final _controller = StreamController<List<Expense>>.broadcast();
  Result<Expense>? createResult;
  Result<Expense>? confirmResult;
  Result<Expense>? updateResult;
  Expense? lastCreated;
  Expense? lastUpdated;
  String? lastConfirmedId;
  String? lastDeletedId;

  void emit(List<Expense> expenses) => _controller.add(expenses);

  @override
  Stream<List<Expense>> watchExpenses(String workspaceId) => _controller.stream;

  @override
  Future<Result<Expense>> createExpense({
    required String workspaceId,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
  }) async {
    final result = createResult ??
        const Result<Expense>.err(ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastCreated = (result as Ok<Expense>).value;
    }
    return result;
  }

  @override
  Future<Result<Expense>> updateExpense(Expense expense) async {
    lastUpdated = expense;
    return updateResult ?? Result.ok(expense);
  }

  @override
  Future<Result<Expense>> confirmExpense(String expenseId) async {
    lastConfirmedId = expenseId;
    return confirmResult ??
        const Result<Expense>.err(ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> deleteExpense(String expenseId) async {
    lastDeletedId = expenseId;
    return const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
