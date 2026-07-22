import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Spese/entrate ricorrenti di un Workspace, in tempo reale (Software
/// Architecture, "Sincronizzazione" — Realtime lato Supabase).
final recurringTransactionsProvider = StreamProvider.autoDispose
    .family<List<RecurringTransactionTemplate>, String>(
  (ref, workspaceId) => ref
      .watch(recurringTransactionRepositoryProvider)
      .watchTemplates(workspaceId),
);

final recurringTransactionFormControllerProvider =
    AsyncNotifierProvider.autoDispose<RecurringTransactionFormController, void>(
        RecurringTransactionFormController.new);

/// Scritto solo dall'AI (tool `create_recurring_transaction`): l'unica azione
/// dell'utente qui è cancellare, coerente con [RecurringTransactionRepository]
/// che non espone alcun metodo di creazione manuale.
class RecurringTransactionFormController
    extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> delete(String templateId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(recurringTransactionRepositoryProvider)
        .deleteTemplate(templateId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
