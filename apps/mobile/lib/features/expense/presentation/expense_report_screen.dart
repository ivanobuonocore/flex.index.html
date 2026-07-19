import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/expense_controller.dart';
import 'create_edit_expense_sheet.dart';

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

/// Report Spese di un Workspace: totale del mese corrente (spese confermate)
/// + lista, più una sezione separata per le spese suggerite dall'AI Engine
/// ancora "in attesa di conferma" (AI Constitution, Principio 1 — l'AI
/// suggerisce, l'utente decide).
class ExpenseReportScreen extends ConsumerWidget {
  const ExpenseReportScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Spese')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateEditExpenseSheet(context, workspaceId: workspaceId),
        child: const Icon(Icons.add),
      ),
      body: expensesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le spese.',
          onRetry: () => ref.invalidate(expensesProvider(workspaceId)),
        ),
        data: (expenses) {
          final now = DateTime.now();
          final confirmed = confirmedThisMonth(expenses, now: now);
          final pending = pendingExpenses(expenses);

          if (confirmed.isEmpty && pending.isEmpty) {
            return EmptyState(
              icon: Icons.euro_outlined,
              title: 'Nessuna spesa ancora',
              message: 'Aggiungi la prima spesa, oppure scrivila in Chat.',
              action: FilledButton(
                onPressed: () => showCreateEditExpenseSheet(context, workspaceId: workspaceId),
                child: const Text('Aggiungi la prima spesa'),
              ),
            );
          }

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
                        'Totale ${_italianMonths[now.month - 1]} ${now.year}',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_formatAmount(totalCents(confirmed)), style: AppTypography.heading1),
                    ],
                  ),
                ),
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Text('In attesa di conferma', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                ...pending.map((expense) => _PendingExpenseTile(expense: expense)),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Text('Spese', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              if (confirmed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Nessuna spesa confermata questo mese.'),
                )
              else
                ...confirmed.map(
                  (expense) => Card(
                    child: ListTile(
                      title: Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_formatDate(expense.occurredAt)),
                      trailing: Text(_formatAmount(expense.amountCents)),
                      onTap: () => showCreateEditExpenseSheet(
                        context,
                        workspaceId: workspaceId,
                        expense: expense,
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

class _PendingExpenseTile extends ConsumerWidget {
  const _PendingExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_formatDate(expense.occurredAt)} · ${_formatAmount(expense.amountCents)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Conferma',
              onPressed: () =>
                  ref.read(expenseFormControllerProvider.notifier).confirm(expense.id),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Scarta',
              onPressed: () =>
                  ref.read(expenseFormControllerProvider.notifier).delete(expense.id),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(int amountCents) => '${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
