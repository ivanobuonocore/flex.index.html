import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [RecurringTransactionRepository] su Supabase Postgres.
/// L'isolamento tra Workspace è garantito dalle policy RLS di
/// `recurring_transaction_templates` (`infrastructure/supabase/migrations`),
/// non da un filtro applicativo qui sotto.
class SupabaseRecurringTransactionRepository
    implements RecurringTransactionRepository {
  SupabaseRecurringTransactionRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'recurring_transaction_templates';

  @override
  Stream<List<RecurringTransactionTemplate>> watchTemplates(
    String workspaceId,
  ) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('next_occurrence_at', ascending: true)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Unit>> deleteTemplate(String templateId) async {
    try {
      await _client
          .from(_table)
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
              'id', templateId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure(
            'Non è stato possibile eliminare la spesa ricorrente.',
            cause: e),
      );
    }
  }

  RecurringTransactionTemplate _toDomain(Map<String, dynamic> row) {
    return RecurringTransactionTemplate(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      type: (row['type'] as String) == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      description: row['description'] as String,
      amountCents: row['amount_cents'] as int,
      category: TransactionCategory.values.byName(row['category'] as String),
      frequency: (row['frequency'] as String) == 'weekly'
          ? RecurrenceFrequency.weekly
          : RecurrenceFrequency.monthly,
      nextOccurrenceAt: DateTime.parse(row['next_occurrence_at'] as String),
      anchorDay: row['anchor_day'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
