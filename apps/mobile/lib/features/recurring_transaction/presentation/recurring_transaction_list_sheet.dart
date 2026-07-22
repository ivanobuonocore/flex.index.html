import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../transaction/application/transaction_category_meta.dart';
import '../application/recurring_transaction_controller.dart';

/// Elenco delle spese/entrate ricorrenti di un Workspace (richiesta esplicita
/// dell'utente: "spese ricorrenti automatiche"). Scritte solo dall'AI in
/// Chat (tool `create_recurring_transaction`) — qui si può solo consultare e
/// cancellare, coerente con [RecurringTransactionRepository].
Future<void> showRecurringTransactionListSheet(
  BuildContext context, {
  required String workspaceId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _RecurringTransactionListSheet(workspaceId: workspaceId),
  );
}

class _RecurringTransactionListSheet extends ConsumerWidget {
  const _RecurringTransactionListSheet({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync =
        ref.watch(recurringTransactionsProvider(workspaceId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ricorrenti', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Scrivi in Chat "il canone Netflix è 15,99€ ogni mese" per '
              'aggiungerne una.',
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            templatesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text(
                  'Non è stato possibile caricare le spese ricorrenti.'),
              data: (templates) {
                if (templates.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Text('Nessuna spesa o entrata ricorrente ancora.'),
                  );
                }
                return Column(
                  children: [
                    for (final template in templates) ...[
                      _RecurringTransactionTile(template: template),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTransactionTile extends ConsumerWidget {
  const _RecurringTransactionTile({required this.template});

  final RecurringTransactionTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = TransactionCategoryMeta.of(template.category);
    final frequencyLabel = template.frequency == RecurrenceFrequency.weekly
        ? 'Ogni settimana'
        : 'Ogni mese';

    return Dismissible(
      key: ValueKey(template.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadii.standardRadius,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => ref
          .read(recurringTransactionFormControllerProvider.notifier)
          .delete(template.id),
      child: Card(
        child: ListTile(
          leading: Icon(meta.icon, color: meta.color),
          title: Text(template.description,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '$frequencyLabel · prossima: ${_formatDate(template.nextOccurrenceAt)}'),
          trailing: Text(
            '${template.type == TransactionType.income ? '+' : '-'}'
            '${_formatAmount(template.amountCents)}',
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa ricorrenza?'),
        content: const Text(
            'Le occorrenze future non verranno più generate. Le transazioni già create restano.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _formatAmount(int amountCents) =>
      '${(amountCents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
