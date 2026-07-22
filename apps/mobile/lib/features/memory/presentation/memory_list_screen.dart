import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/memory_controller.dart';

/// Elenco delle Memorie globali dell'utente (Domain Model, entità Memory).
///
/// Prima slice minima (richiesta esplicita dell'utente): nessun pulsante di
/// creazione manuale — le Memorie nascono solo quando l'utente scrive in
/// Chat "ricorda che..." (vedi tool `remember_fact` in `ai-chat`); qui si
/// possono solo consultare e cancellare (AI Constitution, trasparenza).
class MemoryListScreen extends ConsumerWidget {
  const MemoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(globalMemoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Memoria')),
      body: memoriesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare la memoria.',
          onRetry: () => ref.invalidate(globalMemoriesProvider),
        ),
        data: (memories) {
          if (memories.isEmpty) {
            return const EmptyState(
              icon: Icons.psychology_outlined,
              title: 'Nessuna memoria ancora',
              message: 'Scrivi in Chat "ricorda che..." seguito da '
                  'un\'informazione: l\'assistente la terrà a mente per le '
                  'conversazioni future.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: memories.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final memory = memories[index];
              return Dismissible(
                key: ValueKey(memory.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: AppRadii.standardRadius,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => ref
                    .read(memoryFormControllerProvider.notifier)
                    .delete(memory.id),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      memory.origin == MemoryOrigin.ai
                          ? Icons.auto_awesome_outlined
                          : Icons.person_outline,
                    ),
                    title: Text(memory.content),
                    subtitle: Text(_formatDate(memory.updatedAt)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  /// Conferma prima di eliminare una memoria (richiesta esplicita
  /// dell'utente: "conferma su swipe-to-delete per elementi non banali") —
  /// stessa conferma già presente per la Memoria di Workspace
  /// ([WorkspaceMemoryListScreen]).
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa memoria?'),
        content: const Text('L\'assistente non ne terrà più conto.'),
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
}
