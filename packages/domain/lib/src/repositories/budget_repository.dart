import 'package:pip_shared/pip_shared.dart';

import '../entities/category_budget.dart';
import '../enums.dart';

/// Confine verso la persistenza dei Budget per categoria, implementato nel
/// layer `data` di ogni app (Dependency Inversion — Engineering
/// Constitution, Articolo 4).
abstract interface class BudgetRepository {
  /// Budget dell'utente corrente, una riga per categoria al massimo.
  Stream<List<CategoryBudget>> watchBudgets();

  /// Crea o aggiorna il budget di [category] (upsert su categoria — al più
  /// un budget per categoria per utente).
  Future<Result<CategoryBudget>> setBudget({
    required TransactionCategory category,
    required int monthlyLimitCents,
  });

  Future<Result<Unit>> deleteBudget(String budgetId);
}
