import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/memory_controller.dart';

/// Elenco delle Memorie di un Workspace specifico (richiesta esplicita
/// dell'utente: "Memoria a livello Workspace"). A differenza del Globale
/// (scritto solo dall'AI in Chat, vedi [MemoryListScreen]), qui la creazione
/// è manuale: "Chat unica" ha reso la Chat un'unica conversazione globale per
/// utente, senza modo di sapere a quale Workspace collegare un ricordo.
class WorkspaceMemoryListScreen extends ConsumerWidget {
  const WorkspaceMemoryListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(workspaceMemoriesProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Memoria del Workspace')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: memoriesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare la memoria.',
          onRetry: () => ref.invalidate(workspaceMemoriesProvider(workspaceId)),
        ),
        data: (memories) {
          if (memories.isEmpty) {
            return EmptyState(
              icon: Icons.psychology_outlined,
              title: 'Nessuna memoria ancora',
              message: 'Aggiungi qui informazioni utili da tenere a mente '
                  'per questo Workspace.',
              action: FilledButton(
                onPressed: () => _showAddMemoryDialog(context, ref),
                child: const Text('Aggiungi la prima memoria'),
              ),
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
                    leading: const Icon(Icons.person_outline),
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

  Future<void> _showAddMemoryDialog(BuildContext context, WidgetRef ref) async {
    final content = await showDialog<String>(
      context: context,
      builder: (context) => const _AddMemoryDialog(),
    );
    if (content == null || content.trim().isEmpty) return;
    if (!context.mounted) return;

    final failure = await ref
        .read(memoryFormControllerProvider.notifier)
        .createForWorkspace(workspaceId: workspaceId, content: content);
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// `StatefulWidget` dedicato (non un `TextEditingController` creato e
/// smaltito a mano attorno a `showDialog`): il controller deve restare vivo
/// per tutta l'animazione di chiusura del dialog — disporlo subito dopo
/// `Navigator.pop` lo distrugge mentre il `TextField` è ancora nell'albero
/// durante la transizione, causando "used after being disposed".
class _AddMemoryDialog extends StatefulWidget {
  const _AddMemoryDialog();

  @override
  State<_AddMemoryDialog> createState() => _AddMemoryDialogState();
}

class _AddMemoryDialogState extends State<_AddMemoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuova memoria'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Es. "Il contratto di affitto scade a marzo"',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
