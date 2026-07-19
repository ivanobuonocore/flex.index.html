import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../chat/application/chat_controller.dart';
import '../../document/application/document_controller.dart';
import '../../expense/application/expense_controller.dart';
import '../../note/application/note_controller.dart';
import '../../task/application/task_controller.dart';
import '../application/workspace_controller.dart';

/// Home del Workspace (docs/product/06-information-architecture.md, "Home del
/// Workspace"): nome, descrizione, anteprima Note/Task/Documenti/Chat, menu
/// verso le altre sezioni. Calendario/Knowledge/Memoria/Impostazioni non sono
/// ancora implementate (fasi successive) e vengono mostrate come
/// "Prossimamente" — comunica lo stato reale, non è un placeholder finto.
class WorkspaceDetailScreen extends ConsumerWidget {
  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesProvider);

    return Scaffold(
      body: workspacesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare il Workspace.',
          onRetry: () => ref.invalidate(workspacesProvider),
        ),
        data: (workspaces) {
          Workspace? workspace;
          for (final candidate in workspaces) {
            if (candidate.id == workspaceId) {
              workspace = candidate;
              break;
            }
          }
          if (workspace == null) {
            return const ErrorView(message: 'Workspace non trovato.');
          }
          return _WorkspaceDetailBody(workspace: workspace);
        },
      ),
    );
  }
}

class _WorkspaceDetailBody extends ConsumerWidget {
  const _WorkspaceDetailBody({required this.workspace});

  final Workspace workspace;

  static const _comingSoon = [
    (icon: Icons.event_outlined, label: 'Calendario'),
    (icon: Icons.hub_outlined, label: 'Knowledge Base'),
    (icon: Icons.psychology_outlined, label: 'Memoria'),
    (icon: Icons.settings_outlined, label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notesAsync = ref.watch(notesProvider(workspace.id));
    final tasksAsync = ref.watch(tasksProvider(workspace.id));
    final documentsAsync = ref.watch(documentsProvider(workspace.id));
    final chatsAsync = ref.watch(chatsProvider(workspace.id));
    final expensesAsync = ref.watch(expensesProvider(workspace.id));

    return CustomScrollView(
      slivers: [
        SliverAppBar(title: Text(workspace.name), floating: true),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverList.list(
            children: [
              if (workspace.description != null &&
                  workspace.description!.isNotEmpty) ...[
                Text(workspace.description!, style: AppTypography.body),
                const SizedBox(height: AppSpacing.lg),
              ],
              _SectionHeader(
                title: 'Note',
                onSeeAll: () =>
                    context.push('/workspace/${workspace.id}/notes'),
              ),
              const SizedBox(height: AppSpacing.sm),
              notesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare le note.'),
                data: (notes) => notes.isEmpty
                    ? const _EmptySectionHint(
                        message:
                            'Nessuna nota. Toccando "Vedi tutte" puoi crearne una.',
                      )
                    : Column(
                        children: notes
                            .take(3)
                            .map((note) => Card(
                                  child: ListTile(
                                    title: Text(
                                      note.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => context.push(
                                        '/workspace/${workspace.id}/notes'),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Attività',
                onSeeAll: () =>
                    context.push('/workspace/${workspace.id}/tasks'),
              ),
              const SizedBox(height: AppSpacing.sm),
              tasksAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare le attività.'),
                data: (tasks) => tasks.isEmpty
                    ? const _EmptySectionHint(
                        message:
                            'Nessuna attività. Toccando "Vedi tutte" puoi crearne una.',
                      )
                    : Column(
                        children: tasks
                            .take(3)
                            .map((task) => Card(
                                  child: ListTile(
                                    leading: Icon(
                                      task.status == TaskStatus.done
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                    ),
                                    title: Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => context.push(
                                        '/workspace/${workspace.id}/tasks'),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Documenti',
                onSeeAll: () =>
                    context.push('/workspace/${workspace.id}/documents'),
              ),
              const SizedBox(height: AppSpacing.sm),
              documentsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare i documenti.'),
                data: (documents) => documents.isEmpty
                    ? const _EmptySectionHint(
                        message:
                            'Nessun documento. Toccando "Vedi tutte" puoi caricarne uno.',
                      )
                    : Column(
                        children: documents
                            .take(3)
                            .map((document) => Card(
                                  child: ListTile(
                                    leading: const Icon(
                                        Icons.insert_drive_file_outlined),
                                    title: Text(
                                      document.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => context.push(
                                        '/workspace/${workspace.id}/documents'),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Chat',
                onSeeAll: () => context.push('/workspace/${workspace.id}/chat'),
              ),
              const SizedBox(height: AppSpacing.sm),
              chatsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare le chat.'),
                data: (chats) => chats.isEmpty
                    ? const _EmptySectionHint(
                        message:
                            'Nessuna chat. Toccando "Vedi tutte" puoi crearne una.',
                      )
                    : Column(
                        children: chats
                            .take(3)
                            .map((chat) => Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.chat_bubble_outline),
                                    title: Text(
                                      chat.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => context.push(
                                        '/workspace/${workspace.id}/chat/${chat.id}'),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Spese',
                onSeeAll: () => context.push('/workspace/${workspace.id}/expenses'),
              ),
              const SizedBox(height: AppSpacing.sm),
              expensesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare le spese.'),
                data: (expenses) {
                  final confirmed = confirmedThisMonth(expenses);
                  final pending = pendingExpenses(expenses);
                  if (confirmed.isEmpty && pending.isEmpty) {
                    return const _EmptySectionHint(
                      message:
                          'Nessuna spesa. Toccando "Vedi tutte" puoi aggiungerne una.',
                    );
                  }
                  final totalLabel =
                      '${(totalCents(confirmed) / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.euro_outlined),
                      title: Text('Totale questo mese: $totalLabel'),
                      subtitle: pending.isNotEmpty
                          ? Text('${pending.length} in attesa di conferma')
                          : null,
                      onTap: () => context.push('/workspace/${workspace.id}/expenses'),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Prossimamente', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: _comingSoon
                      .map((entry) => ListTile(
                            leading:
                                Icon(entry.icon, color: theme.disabledColor),
                            title: Text(
                              entry.label,
                              style: TextStyle(color: theme.disabledColor),
                            ),
                            trailing: Text(
                              'In arrivo',
                              style: AppTypography.caption
                                  .copyWith(color: theme.disabledColor),
                            ),
                          ))
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.heading3),
        TextButton(onPressed: onSeeAll, child: const Text('Vedi tutte')),
      ],
    );
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: AppTypography.body
          .copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
    );
  }
}
