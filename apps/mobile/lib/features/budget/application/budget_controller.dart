import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Budget per categoria dell'utente corrente, in tempo reale (Software
/// Architecture, "Sincronizzazione" — Realtime lato Supabase).
final budgetsProvider = StreamProvider.autoDispose<List<CategoryBudget>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchBudgets(),
);

final budgetFormControllerProvider =
    AsyncNotifierProvider.autoDispose<BudgetFormController, void>(
        BudgetFormController.new);

class BudgetFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> setBudget({
    required TransactionCategory category,
    required int monthlyLimitCents,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(budgetRepositoryProvider).setBudget(
          category: category,
          monthlyLimitCents: monthlyLimitCents,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> deleteBudget(String budgetId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(budgetRepositoryProvider).deleteBudget(budgetId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
