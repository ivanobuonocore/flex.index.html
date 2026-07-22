import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../recurring_transaction/presentation/recurring_transaction_list_sheet.dart';
import '../../workspace/application/workspace_sharing_controller.dart';
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
    // Permessi granulari sui Workspace condivisi (integrazione richiesta
    // esplicitamente): `null` per un Workspace personale o per il
    // proprietario di uno condiviso, sempre accesso pieno in entrambi i
    // casi — solo un membro con ruolo `viewer` viene limitato qui.
    final isViewer = ref.watch(currentMemberRoleProvider(workspaceId)) ==
        WorkspaceRole.viewer;

    return Scaffold(
      appBar: GradientAppBar(
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
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton(
              onPressed: () => showCreateEditTransactionSheet(context,
                  workspaceId: workspaceId),
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
              message: isViewer
                  ? 'Non ci sono ancora transazioni in questo Bilancio.'
                  : 'Aggiungi entrate o uscite, oppure scrivile in Chat.',
              action: isViewer
                  ? null
                  : FilledButton(
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
              _BalanceHeroCard(
                month: now,
                balanceCents: balance,
                incomeCents: income,
                expenseCents: expense,
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('In attesa di conferma', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                ...pending.map((transaction) => _PendingTransactionTile(
                    transaction: transaction, readOnly: isViewer)),
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
                      onTap: isViewer
                          ? null
                          : () => showCreateEditTransactionSheet(
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
  const _PendingTransactionTile(
      {required this.transaction, this.readOnly = false});

  final Transaction transaction;

  /// `true` per un membro con ruolo `viewer` (permessi granulari,
  /// integrazione richiesta esplicitamente): confermare/scartare è
  /// un'azione di scrittura come le altre.
  final bool readOnly;

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
        trailing: readOnly
            ? null
            : Row(
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

/// Saldo del mese in evidenza, stesso trattamento gradiente "premium" già
/// usato in balance_overview_screen.dart (redesign estetico 2.0) — le due
/// schermate di Bilancio (globale e di un singolo Workspace) restavano
/// visivamente incoerenti tra loro prima di questa slice.
class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({
    required this.month,
    required this.balanceCents,
    required this.incomeCents,
    required this.expenseCents,
  });

  final DateTime month;
  final int balanceCents;
  final int incomeCents;
  final int expenseCents;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.cardPremiumRadius,
        boxShadow: AppShadows.glow(
          color: AppColors.heroGradient.first,
          isDark: isDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo ${_italianMonths[month.month - 1]} ${month.year}',
            style: AppTypography.caption
                .copyWith(color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatSignedAmount(balanceCents),
            style: AppTypography.heading1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroStatPill(
                  emoji: '💰',
                  label: 'Entrate',
                  amountCents: incomeCents,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroStatPill(
                  emoji: '💸',
                  label: 'Uscite',
                  amountCents: expenseCents,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pillola statistica dentro l'hero del saldo (Entrate/Uscite) — sfondo
/// bianco traslucido, stesso trattamento di `_HeroStatPill` in
/// balance_overview_screen.dart (senza tocco per il dettaglio per categoria:
/// questa schermata non ha un breakdown per categoria separato dall'elenco
/// già visibile sotto).
class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.emoji,
    required this.label,
    required this.amountCents,
  });

  final String emoji;
  final String label;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withOpacity(0.8)),
                ),
                Text(
                  _formatAmount(amountCents),
                  style: AppTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
