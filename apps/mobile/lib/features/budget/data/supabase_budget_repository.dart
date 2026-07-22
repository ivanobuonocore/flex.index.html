import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [BudgetRepository] su Supabase Postgres. L'isolamento
/// tra utenti è garantito dalle policy RLS di `category_budgets`
/// (`infrastructure/supabase/migrations`), non da un filtro applicativo qui
/// sotto.
class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'category_budgets';

  @override
  Stream<List<CategoryBudget>> watchBudgets() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('category')
        .map((rows) => rows.map(_toDomain).toList(growable: false));
  }

  @override
  Future<Result<CategoryBudget>> setBudget({
    required TransactionCategory category,
    required int monthlyLimitCents,
  }) async {
    if (monthlyLimitCents <= 0) {
      return const Result.err(
          ValidationFailure('Il budget deve essere maggiore di zero.'));
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(
          AuthFailure('Devi accedere per impostare un budget.'));
    }

    try {
      final row = await _client
          .from(_table)
          .upsert(
            {
              'user_id': userId,
              'category': category.name,
              'monthly_limit_cents': monthlyLimitCents,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'user_id,category',
          )
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile salvare il budget.', cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteBudget(String budgetId) async {
    try {
      await _client.from(_table).delete().eq('id', budgetId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare il budget.',
            cause: e),
      );
    }
  }

  CategoryBudget _toDomain(Map<String, dynamic> row) {
    return CategoryBudget(
      id: row['id'] as String,
      category: TransactionCategory.values.byName(row['category'] as String),
      monthlyLimitCents: row['monthly_limit_cents'] as int,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
