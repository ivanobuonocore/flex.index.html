import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [ExpenseRepository] su Supabase Postgres. L'isolamento
/// tra Workspace è garantito dalle policy RLS di `expenses`
/// (`infrastructure/supabase/migrations`), non dal filtro applicativo qui
/// sotto — stesso principio di [SupabaseTaskRepository].
class SupabaseExpenseRepository implements ExpenseRepository {
  SupabaseExpenseRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'expenses';

  @override
  Stream<List<Expense>> watchExpenses(String workspaceId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('occurred_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Expense>> createExpense({
    required String workspaceId,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
  }) async {
    if (description.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('La descrizione della spesa è obbligatoria.'));
    }
    if (amountCents <= 0) {
      return const Result.err(
          ValidationFailure('L\'importo deve essere maggiore di zero.'));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'workspace_id': workspaceId,
            'description': description.trim(),
            'amount_cents': amountCents,
            'currency': currency,
            'occurred_at': occurredAt.toIso8601String(),
            'status': ExpenseStatus.confirmed.name,
            'created_by_ai': false,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
          UnexpectedFailure('Non è stato possibile creare la spesa.', cause: e));
    }
  }

  @override
  Future<Result<Expense>> updateExpense(Expense expense) async {
    if (expense.description.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('La descrizione della spesa è obbligatoria.'));
    }
    if (expense.amountCents <= 0) {
      return const Result.err(
          ValidationFailure('L\'importo deve essere maggiore di zero.'));
    }

    try {
      final row = await _client
          .from(_table)
          .update({
            'description': expense.description.trim(),
            'amount_cents': expense.amountCents,
            'occurred_at': expense.occurredAt.toIso8601String(),
          })
          .eq('id', expense.id)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aggiornare la spesa.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Expense>> confirmExpense(String expenseId) async {
    try {
      final row = await _client
          .from(_table)
          .update({'status': ExpenseStatus.confirmed.name})
          .eq('id', expenseId)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile confermare la spesa.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteExpense(String expenseId) async {
    try {
      await _client
          .from(_table)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', expenseId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare la spesa.',
            cause: e),
      );
    }
  }

  Expense _toDomain(Map<String, dynamic> row) {
    return Expense(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      chatId: row['chat_id'] as String?,
      description: row['description'] as String,
      amountCents: row['amount_cents'] as int,
      currency: row['currency'] as String,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      status: ExpenseStatus.values.byName(row['status'] as String),
      createdByAi: row['created_by_ai'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
    );
  }
}
