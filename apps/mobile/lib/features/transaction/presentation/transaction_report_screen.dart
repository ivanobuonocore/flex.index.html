import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../recurring_transaction/presentation/recurring_transaction_list_sheet.dart';
import '../application/transaction_category_meta.dart';
import '../application/transaction_controller.dart';
import 'create_edit_transaction_sheet.dart';

const _italianMonths = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

/// Bilancio di un Workspace: saldo del mese corrente (entrate − uscite
/// confermate) + lista, più una sezione separata per le transazioni suggerite
/// dall'AI Engine ancora "in attesa di conferma" (AI Constitution, Principio
/// 1 — l'AI suggerisce, l'utente decide).
class TransactionReportScreen extends ConsumerWidget {
  const TransactionReportScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilancio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Spese ricorrenti',
            onPressed: () => showRecurringTransactionListSheet(context,
                workspaceId: workspaceId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateEditTransactionSheet(context, workspaceId: workspaceId),
        child: const Icon(Icons.add),
      ),
      body: transactionsAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare il bilancio.',
          onRetry: () => ref.invalidate(transactionsProvider(workspaceId)),
        ),
        data: (transactions) {
          final now = DateTime.now();
          final confirmed = confirmedThisMonth(transactions, now: now);
          final pending = pendingTransactions(transactions);

          if (confirmed.isEmpty && pending.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.categoryBilancio,
              title: 'Nessuna transazione ancora',
              message: 'Aggiungi entrate o uscite, oppure scrivile in Chat.',
              action: FilledButton(
                onPressed: () => showCreateEditTransactionSheet(context,
                    workspaceId: workspaceId),
                child: const Text('Aggiungi la prima transazione'),
              ),
            );
          }

          final balance = balanceCents(confirmed);
          final income = totalIncomeCents(confirmed);
          final expense = totalExpenseCents(confirmed);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo ${_italianMonths[now.month - 1]} ${now.year}',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_formatSignedAmount(balance),
                          style: AppTypography.heading1),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Entrate: ${_formatAmount(income)}'),
                          const SizedBox(width: AppSpacing.md),
                          Icon(Icons.remove_circle_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Text('Uscite: ${_formatAmount(expense)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('In attesa di conferma', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                ...pending.map((transaction) =>
                    _PendingTransactionTile(transaction: transaction)),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Transazioni', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              if (confirmed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Nessuna transazione confermata questo mese.'),
                )
              else
                ...confirmed.map(
                  (transaction) => Card(
                    child: ListTile(
                      leading: Icon(
                        transaction.type == TransactionType.income
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: transaction.type == TransactionType.income
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      title: Text(transaction.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_formatDate(transaction.occurredAt)} · '),
                          _CategoryBadge(category: transaction.category),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (transaction.documentId != null) ...[
                            Icon(Icons.receipt_long_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5)),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Text(_formatAmount(transaction.amountCents)),
                        ],
                      ),
                      onTap: () => showCreateEditTransactionSheet(
                        context,
                        workspaceId: workspaceId,
                        transaction: transaction,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PendingTransactionTile extends ConsumerWidget {
  const _PendingTransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(
          transaction.type == TransactionType.income
              ? Icons.add_circle_outline
              : Icons.remove_circle_outline,
        ),
        title: Text(transaction.description,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${_formatDate(transaction.occurredAt)} · ${_formatAmount(transaction.amountCents)} · '),
            _CategoryBadge(category: transaction.category),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Conferma',
              onPressed: () => ref
                  .read(transactionFormControllerProvider.notifier)
                  .confirm(transaction.id),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Scarta',
              onPressed: () => ref
                  .read(transactionFormControllerProvider.notifier)
                  .delete(transaction.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icona colorata + etichetta di una categoria (redesign estetico —
/// richiesta esplicita dell'utente: "icone colorate"), riusata ovunque il
/// Bilancio elenca una transazione.
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final TransactionCategory category;

  @override
  Widget build(BuildContext context) {
    final meta = TransactionCategoryMeta.of(category);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(meta.icon, size: 14, color: meta.color),
        const SizedBox(width: 2),
        Text(meta.label),
      ],
    );
  }
}

String _formatAmount(int amountCents) =>
    '${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _formatSignedAmount(int amountCents) {
  final sign = amountCents > 0 ? '+' : (amountCents < 0 ? '-' : '');
  return '$sign${_formatAmount(amountCents.abs())}';
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
