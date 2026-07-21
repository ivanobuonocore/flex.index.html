import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/workspace_controller.dart';
import 'create_workspace_sheet.dart';
import 'widgets/workspace_card.dart';

/// Home di Workspace (docs/product/06-information-architecture.md, "Workspace"
/// — "il cuore dell'app").
class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesProvider);

    return Scaffold(
      // Titolo "Spazi" (rinominato da "Workspace" — richiesta esplicita
      // dell'utente): il modello di dominio/le route restano "Workspace",
      // solo l'etichetta mostrata cambia.
      appBar: AppBar(title: const Text('Spazi')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateWorkspaceSheet(context),
        child: const Icon(Icons.add),
      ),
      body: workspacesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare i tuoi Workspace.',
          onRetry: () => ref.invalidate(workspacesProvider),
        ),
        data: (workspaces) {
          if (workspaces.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Nessun Workspace ancora',
              message:
                  'Crea il tuo primo Workspace per organizzare chat, documenti e attività.',
              action: FilledButton(
                onPressed: () => showCreateWorkspaceSheet(context),
                child: const Text('Crea il primo Workspace'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: workspaces.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final workspace = workspaces[index];
              return WorkspaceCard(
                workspace: workspace,
                // La sezione Appuntamenti apre direttamente il calendario
                // (richiesta esplicita dell'utente: "vorrei vedere il
                // calendario"), non l'anteprima generica del Workspace —
                // da lì il calendario era raggiungibile solo con un tocco
                // in più su "vedi tutti".
                onTap: () => context.push(
                  workspace.category == SystemWorkspaceCategory.appuntamenti
                      ? '/workspace/${workspace.id}/reminders'
                      : '/workspace/${workspace.id}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
