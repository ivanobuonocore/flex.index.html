import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository({this.setResult, this.deleteResult});

  final _controller = StreamController<List<CategoryBudget>>.broadcast();
  Result<CategoryBudget>? setResult;
  Result<Unit>? deleteResult;
  TransactionCategory? lastSetCategory;
  int? lastSetMonthlyLimitCents;
  String? lastDeletedId;

  void emit(List<CategoryBudget> budgets) => _controller.add(budgets);

  @override
  Stream<List<CategoryBudget>> watchBudgets() => _controller.stream;

  @override
  Future<Result<CategoryBudget>> setBudget({
    required TransactionCategory category,
    required int monthlyLimitCents,
  }) async {
    lastSetCategory = category;
    lastSetMonthlyLimitCents = monthlyLimitCents;
    return setResult ??
        const Result<CategoryBudget>.err(
            ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> deleteBudget(String budgetId) async {
    lastDeletedId = budgetId;
    return deleteResult ?? const Result.ok(unit);
  }

  void dispose() => _controller.close();
}
