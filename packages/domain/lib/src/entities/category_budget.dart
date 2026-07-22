import '../enums.dart';

/// Soglia mensile di spesa per una categoria del Bilancio personale
/// (richiesta esplicita dell'utente: "budget per categoria"). Legata
/// all'utente, non a un Workspace: valutata contro lo stesso aggregato
/// multi-Workspace già usato da [BalanceOverviewScreen]/`query_balance_summary`
/// (tutti i Workspace personali, esclusi i Bilanci condivisi) — un budget "per
/// Workspace" non avrebbe un confronto naturale con quella vista.
final class CategoryBudget {
  const CategoryBudget({
    required this.id,
    required this.category,
    required this.monthlyLimitCents,
    required this.updatedAt,
  });

  final String id;
  final TransactionCategory category;

  /// Sempre positivo (mai zero): un budget a zero non ha senso, si cancella
  /// il budget invece di impostarlo a zero.
  final int monthlyLimitCents;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is CategoryBudget &&
      other.id == id &&
      other.category == category &&
      other.monthlyLimitCents == monthlyLimitCents &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, category, monthlyLimitCents, updatedAt);

  @override
  String toString() =>
      'CategoryBudget(id: $id, category: $category, monthlyLimitCents: $monthlyLimitCents)';
}
