import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [TransactionRepository] su Supabase Postgres.
/// L'isolamento tra Workspace è garantito dalle policy RLS di `transactions`
/// (`infrastructure/supabase/migrations`), non dal filtro applicativo qui
/// sotto — stesso principio di [SupabaseTaskRepository].
class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'transactions';

  @override
  Stream<List<Transaction>> watchTransactions(String? workspaceId) {
    final query = _client.from(_table).stream(primaryKey: ['id']);
    final scoped =
        workspaceId == null ? query : query.eq('workspace_id', workspaceId);
    return scoped.order('occurred_at', ascending: false).map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(_toDomain)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Transaction>> createTransaction({
    required String workspaceId,
    required TransactionType type,
    required String description,
    required int amountCents,
    String currency = 'EUR',
    required DateTime occurredAt,
    TransactionCategory category = TransactionCategory.altro,
    List<String> tags = const [],
  }) async {
    if (description.trim().isEmpty) {
      return const Result.err(ValidationFailure(
          'La descrizione della transazione è obbligatoria.'));
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
            'type': type.name,
            'description': description.trim(),
            'amount_cents': amountCents,
            'currency': currency,
            'occurred_at': occurredAt.toIso8601String(),
            'status': TransactionStatus.confirmed.name,
            'created_by_ai': false,
            'category': category.name,
            'tags': tags,
          })
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(UnexpectedFailure(
          'Non è stato possibile creare la transazione.',
          cause: e));
    }
  }

  @override
  Future<Result<Transaction>> updateTransaction(Transaction transaction) async {
    if (transaction.description.trim().isEmpty) {
      return const Result.err(ValidationFailure(
          'La descrizione della transazione è obbligatoria.'));
    }
    if (transaction.amountCents <= 0) {
      return const Result.err(
          ValidationFailure('L\'importo deve essere maggiore di zero.'));
    }

    try {
      final row = await _client
          .from(_table)
          .update({
            'description': transaction.description.trim(),
            'amount_cents': transaction.amountCents,
            'occurred_at': transaction.occurredAt.toIso8601String(),
            'category': transaction.category.name,
            'tags': transaction.tags,
          })
          .eq('id', transaction.id)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aggiornare la transazione.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Transaction>> confirmTransaction(String transactionId) async {
    try {
      final row = await _client
          .from(_table)
          .update({'status': TransactionStatus.confirmed.name})
          .eq('id', transactionId)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile confermare la transazione.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteTransaction(String transactionId) async {
    try {
      await _client
          .from(_table)
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
              'id', transactionId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare la transazione.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Transaction>> attachDocument({
    required String transactionId,
    required String? documentId,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .update({'document_id': documentId})
          .eq('id', transactionId)
          .select()
          .single();
      return Result.ok(_toDomain(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile allegare lo scontrino.',
            cause: e),
      );
    }
  }

  Transaction _toDomain(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      chatId: row['chat_id'] as String?,
      type: TransactionType.values.byName(row['type'] as String),
      description: row['description'] as String,
      amountCents: row['amount_cents'] as int,
      currency: row['currency'] as String,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      status: TransactionStatus.values.byName(row['status'] as String),
      createdByAi: row['created_by_ai'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
      deletedAt: row['deleted_at'] != null
          ? DateTime.parse(row['deleted_at'] as String)
          : null,
      category: TransactionCategory.values.byName(row['category'] as String),
      documentId: row['document_id'] as String?,
      tags: (row['tags'] as List<dynamic>).cast<String>(),
    );
  }
}
