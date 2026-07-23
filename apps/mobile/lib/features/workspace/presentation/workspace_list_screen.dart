import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
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
      appBar: const GradientAppBar(title: Text('Spazi')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateWorkspaceSheet(context),
        child: const Icon(Icons.add),
      ),
      body: workspacesAsync.when(
        loading: () => const SkeletonList(),
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
            itemCount: workspaces.length + 2,
            separatorBuilder: (_, index) => SizedBox(
              height: index == 0 ? AppSpacing.lg : AppSpacing.sm,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SpacesHero(
                  count: workspaces.length,
                  onCreate: () => showCreateWorkspaceSheet(context),
                );
              }
              if (index == 1) {
                return Text('I tuoi spazi', style: AppTypography.heading3);
              }

              final workspace = workspaces[index - 2];
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

/// Rende la lista una vera pagina di ingresso: prima della lista l'utente
/// vede quante aree ha a disposizione e come crearne una nuova, invece di
/// trovarsi direttamente davanti a una sequenza di card.
class _SpacesHero extends StatelessWidget {
  const _SpacesHero({required this.count, required this.onCreate});

  final int count;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: AppRadii.buttonRadius,
                ),
                child: const Icon(Icons.space_dashboard_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'spazio attivo' : 'spazi attivi'}',
                  style: AppTypography.heading3.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Organizza progetti, attività e documenti in un unico posto.',
            style: AppTypography.body.copyWith(
              color: Colors.white.withOpacity(0.86),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuovo spazio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.65)),
            ),
          ),
        ],
      ),
    );
  }
}
