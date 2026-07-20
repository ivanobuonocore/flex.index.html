import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../document/application/document_controller.dart';
import '../../../task/application/task_controller.dart';
import '../../../transaction/application/transaction_controller.dart';

/// Anteprima viva per la striscia "Sezioni" (Fase 3, "Sezioni fisse" —
/// richiesta esplicita dell'utente): a colpo d'occhio, non solo il nome
/// della sezione. Riusa i provider già esistenti di ciascuna feature — nessun
/// nuovo stato, solo una lettura in più della stessa fonte di verità.
class SectionPreview extends StatelessWidget {
  const SectionPreview(
      {super.key, required this.category, required this.workspaceId});

  final String category;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return switch (category) {
      SystemWorkspaceCategory.bilancio =>
        _BilancioPreview(workspaceId: workspaceId),
      SystemWorkspaceCategory.attivita =>
        _AttivitaPreview(workspaceId: workspaceId),
      SystemWorkspaceCategory.documenti =>
        _DocumentiPreview(workspaceId: workspaceId),
      // Appuntamenti: nessuna entità/repository ancora costruita (prossima slice).
      _ => const _PreviewText('Presto disponibile'),
    };
  }
}

class _BilancioPreview extends ConsumerWidget {
  const _BilancioPreview({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider(workspaceId));
    return transactionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (transactions) {
        final confirmed = confirmedThisMonth(transactions);
        if (confirmed.isEmpty) {
          return const _PreviewText('Nessuna spesa registrata questo mese');
        }
        final balance = balanceCents(confirmed);
        final sign = balance > 0 ? '+' : (balance < 0 ? '-' : '');
        final amount =
            (balance.abs() / 100).toStringAsFixed(2).replaceAll('.', ',');
        return _PreviewText(
          'Saldo del mese: $sign$amount €',
          color: balance < 0 ? AppColors.error : AppColors.success,
        );
      },
    );
  }
}

class _AttivitaPreview extends ConsumerWidget {
  const _AttivitaPreview({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(workspaceId));
    return tasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tasks) {
        final open = tasks.where((t) => t.status != TaskStatus.done).length;
        return _PreviewText(
          open == 0 ? 'Nessuna attività aperta' : '$open attività aperte',
        );
      },
    );
  }
}

class _DocumentiPreview extends ConsumerWidget {
  const _DocumentiPreview({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider(workspaceId));
    return documentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (documents) => _PreviewText(
        documents.isEmpty
            ? 'Nessun documento'
            : '${documents.length} documenti',
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption.copyWith(
        color:
            color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}
