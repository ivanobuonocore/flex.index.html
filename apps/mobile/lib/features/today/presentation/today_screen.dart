import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../auth/application/session_controller.dart';
import '../../workspace/application/workspace_controller.dart';
import '../../workspace/presentation/create_workspace_sheet.dart';
import '../../workspace/presentation/widgets/workspace_card.dart';

/// Today (docs/product/06-information-architecture.md, "Today"): punto di
/// partenza della giornata. In Fase 1 mostra saluto e Workspace recenti —
/// attività, promemoria e suggerimenti AI arrivano con Fase 2/3/4, quando
/// esistono i dati reali da mostrare (niente elementi decorativi senza
/// funzione, docs/product/05-design-system.md).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionControllerProvider).value;
    final workspacesAsync = ref.watch(workspacesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateWorkspaceSheet(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(_greeting(user?.name), style: AppTypography.heading1),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ecco dove hai lasciato le cose.',
              style: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Workspace recenti', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            workspacesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text(
                'Non è stato possibile caricare i Workspace.',
                style: AppTypography.body,
              ),
              data: (workspaces) {
                if (workspaces.isEmpty) {
                  return Text(
                    'Nessun Workspace ancora. Creane uno con il pulsante +.',
                    style: AppTypography.body.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  );
                }
                final recent = workspaces.take(5).toList(growable: false);
                return Column(
                  children: [
                    for (final workspace in recent) ...[
                      WorkspaceCard(workspace: workspace),
                      const SizedBox(height: AppSpacing.sm),
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

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final moment = hour < 12
        ? 'Buongiorno'
        : (hour < 18 ? 'Buon pomeriggio' : 'Buonasera');
    return name == null || name.isEmpty ? moment : '$moment, $name';
  }
}
