import 'package:pip_shared/pip_shared.dart';

import '../entities/recurring_transaction_template.dart';

/// Confine verso la persistenza dei modelli di Transazione ricorrente,
/// implementato nel layer `data` di ogni app (Dependency Inversion —
/// Engineering Constitution, Articolo 4).
///
/// Scritto solo dall'AI Engine (tool `create_recurring_transaction`): nessun
/// metodo di creazione qui, coerente con [MemoryRepository] per il livello
/// Globale.
abstract interface class RecurringTransactionRepository {
  /// Modelli ricorrenti del Workspace [workspaceId].
  Stream<List<RecurringTransactionTemplate>> watchTemplates(
    String workspaceId,
  );

  Future<Result<Unit>> deleteTemplate(String templateId);
}
