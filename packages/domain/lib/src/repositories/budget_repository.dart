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

  /// Notifica push se [spentCents] supera l'80% o il 100% di [limitCents]
  /// (integrazione richiesta esplicitamente: "notifica push su budget quasi
  /// superato"). Chiamata subito dopo che una Transazione di spesa è stata
  /// confermata/creata, non su una schedulazione periodica — l'evento è
  /// deterministico in quel momento. Non invia due volte la stessa soglia
  /// nello stesso mese (stato tracciato lato server, mai dal client).
  Future<Result<Unit>> checkBudgetAlert({
    required String budgetId,
    required TransactionCategory category,
    required int spentCents,
    required int limitCents,
  });
}
