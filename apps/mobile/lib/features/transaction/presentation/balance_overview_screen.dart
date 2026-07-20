import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../workspace/application/workspace_controller.dart';
import '../application/transaction_category_meta.dart';
import '../application/transaction_controller.dart';

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

/// Bilancio globale (docs/product/06-information-architecture.md — nuova
/// quinta voce di navigazione, richiesta esplicita dell'utente): a differenza
/// di [TransactionReportScreen] (un solo Workspace), qui `workspaceId` è
/// sempre `null` — aggrega le transazioni di **tutti** i Workspace
/// dell'utente in un unico grafico a torta entrate/uscite, così le spese
/// scritte in Chat (in qualsiasi Workspace, o privatamente) confluiscono in
/// un prospetto unico. Stesso principio "l'AI suggerisce, l'utente decide":
/// nessuna transazione pending conta nel saldo o nel grafico.
class BalanceOverviewScreen extends ConsumerWidget {
  const BalanceOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider(null));
    final workspacesAsync = ref.watch(workspacesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bilancio')),
      body: transactionsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare il bilancio.',
          onRetry: () => ref.invalidate(transactionsProvider(null)),
        ),
        data: (transactions) {
          final now = DateTime.now();
          final confirmed = confirmedThisMonth(transactions, now: now);
          final pending = pendingTransactions(transactions);

          if (confirmed.isEmpty && pending.isEmpty) {
            return const EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Nessuna transazione ancora',
              message:
                  'Scrivi una spesa o un\'entrata in una Chat (es. "barbiere 23€") oppure '
                  'aggiungila dal Bilancio di un Workspace: qui troverai il quadro d\'insieme.',
            );
          }

          final workspaces = workspacesAsync.value ?? const [];
          final workspaceNames = <String, String>{
            for (final workspace in workspaces) workspace.id: workspace.name,
          };

          final income = totalIncomeCents(confirmed);
          final expense = totalExpenseCents(confirmed);
          final balance = balanceCents(confirmed);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                'Panoramica ${_italianMonths[now.month - 1]} ${now.year}',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tutti i Workspace',
                style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _BalancePieChart(incomeCents: income, expenseCents: expense),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo del mese', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.xs),
                      Text(_formatSignedAmount(balance),
                          style: AppTypography.heading1),
                      const SizedBox(height: AppSpacing.sm),
                      _LegendRow(
                        color: AppColors.success,
                        label: 'Entrate',
                        amountCents: income,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _LegendRow(
                        color: AppColors.error,
                        label: 'Uscite',
                        amountCents: expense,
                      ),
                    ],
                  ),
                ),
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('In attesa di conferma', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                for (final transaction in pending) ...[
                  _PendingTransactionTile(
                    transaction: transaction,
                    workspaceName:
                        workspaceNames[transaction.workspaceId] ?? 'Workspace',
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Transazioni confermate', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              if (confirmed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Nessuna transazione confermata questo mese.'),
                )
              else
                for (final transaction in confirmed)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        transaction.type == TransactionType.income
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        color: transaction.type == TransactionType.income
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      title: Text(transaction.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${workspaceNames[transaction.workspaceId] ?? "Workspace"} · '
                            '${_formatDate(transaction.occurredAt)} · ',
                          ),
                          _CategoryBadge(category: transaction.category),
                        ],
                      ),
                      trailing: Text(_formatAmount(transaction.amountCents)),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _BalancePieChart extends StatelessWidget {
  const _BalancePieChart(
      {required this.incomeCents, required this.expenseCents});

  final int incomeCents;
  final int expenseCents;

  @override
  Widget build(BuildContext context) {
    final total = incomeCents + expenseCents;

    if (total == 0) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Nessun importo confermato questo mese.')),
      );
    }

    final incomePercent = incomeCents / total * 100;
    final expensePercent = expenseCents / total * 100;

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 48,
          sections: [
            if (incomeCents > 0)
              PieChartSectionData(
                value: incomeCents.toDouble(),
                color: AppColors.success,
                title: '${incomePercent.toStringAsFixed(0)}%',
                radius: 64,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (expenseCents > 0)
              PieChartSectionData(
                value: expenseCents.toDouble(),
                color: AppColors.error,
                title: '${expensePercent.toStringAsFixed(0)}%',
                radius: 64,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(
      {required this.color, required this.label, required this.amountCents});

  final Color color;
  final String label;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
        const Spacer(),
        Text(_formatAmount(amountCents),
            style: AppTypography.body.copyWith(color: color)),
      ],
    );
  }
}

class _PendingTransactionTile extends ConsumerWidget {
  const _PendingTransactionTile(
      {required this.transaction, required this.workspaceName});

  final Transaction transaction;
  final String workspaceName;

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
              '$workspaceName · ${_formatDate(transaction.occurredAt)} · '
              '${_formatAmount(transaction.amountCents)} · ',
            ),
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
