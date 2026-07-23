import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../document/application/document_controller.dart';
import '../../memory/application/memory_controller.dart';
import '../../note/application/note_controller.dart';
import '../../note/presentation/create_edit_note_sheet.dart';
import '../../reminder/application/calendar_event_controller.dart';
import '../../reminder/presentation/create_reminder_sheet.dart';
import '../../task/application/task_controller.dart';
import '../../task/presentation/create_edit_task_sheet.dart';
import '../../transaction/application/transaction_controller.dart';
import '../../transaction/presentation/create_edit_transaction_sheet.dart';
import '../application/workspace_controller.dart';
import '../application/workspace_sharing_controller.dart';

/// Home del Workspace (docs/product/06-information-architecture.md, "Home del
/// Workspace"): nome, descrizione, anteprima Note/Task/Documenti/Bilancio/
/// Promemoria/Memoria, menu verso le altre sezioni. Knowledge/Impostazioni
/// non sono ancora implementate (fasi successive) e vengono mostrate come
/// "Prossimamente" — comunica lo stato reale, non è un placeholder finto.
class WorkspaceDetailScreen extends ConsumerWidget {
  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspacesProvider);
    // Permessi granulari sui Workspace condivisi (stesso principio già
    // applicato a ogni altro pulsante di creazione nelle schermate di un
    // Workspace condiviso): un membro con ruolo `viewer` non vede il FAB.
    final isViewer = ref.watch(currentMemberRoleProvider(workspaceId)) ==
        WorkspaceRole.viewer;

    return Scaffold(
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton(
              onPressed: () => _showQuickActions(context, workspaceId),
              child: const Icon(Icons.add),
            ),
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
    (icon: Icons.hub_outlined, label: 'Knowledge Base'),
    (icon: Icons.settings_outlined, label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notesAsync = ref.watch(notesProvider(workspace.id));
    final tasksAsync = ref.watch(tasksProvider(workspace.id));
    final documentsAsync = ref.watch(documentsProvider(workspace.id));
    final transactionsAsync = ref.watch(transactionsProvider(workspace.id));
    final eventsAsync = ref.watch(calendarEventsProvider(workspace.id));
    final memoriesAsync = ref.watch(workspaceMemoriesProvider(workspace.id));

    return CustomScrollView(
      slivers: [
        // Stesso gradiente "premium" già usato da GradientAppBar (redesign
        // estetico 2.0) — qui applicato via `flexibleSpace` invece del widget
        // condiviso perché questa schermata usa uno SliverAppBar dentro un
        // CustomScrollView (per il comportamento `floating`), non un AppBar
        // semplice compatibile con `Scaffold.appBar`.
        SliverAppBar(
          title: Text(workspace.name),
          floating: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppShadows.glow(
                color: AppColors.heroGradient.first,
                isDark: theme.brightness == Brightness.dark,
              ),
            ),
          ),
        ),
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
                title: 'Bilancio',
                onSeeAll: () =>
                    context.push('/workspace/${workspace.id}/transactions'),
              ),
              const SizedBox(height: AppSpacing.sm),
              transactionsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare il bilancio.'),
                data: (transactions) {
                  final confirmed = confirmedThisMonth(transactions);
                  final pending = pendingTransactions(transactions);
                  if (confirmed.isEmpty && pending.isEmpty) {
                    return const _EmptySectionHint(
                      message:
                          'Nessuna transazione. Toccando "Vedi tutte" puoi aggiungerne una.',
                    );
                  }
                  final balance = balanceCents(confirmed);
                  final sign = balance > 0 ? '+' : (balance < 0 ? '-' : '');
                  final balanceLabel =
                      '$sign${(balance.abs() / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
                  return Card(
                    child: ListTile(
                      leading:
                          const Icon(Icons.account_balance_wallet_outlined),
                      title: Text('Saldo questo mese: $balanceLabel'),
                      subtitle: pending.isNotEmpty
                          ? Text('${pending.length} in attesa di conferma')
                          : null,
                      onTap: () => context
                          .push('/workspace/${workspace.id}/transactions'),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Promemoria',
                onSeeAll: () =>
                    context.push('/workspace/${workspace.id}/reminders'),
              ),
              const SizedBox(height: AppSpacing.sm),
              eventsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare i promemoria.'),
                data: (events) {
                  final upcoming = events
                      .where((e) => e.startsAt.isAfter(DateTime.now()))
                      .toList();
                  if (upcoming.isEmpty) {
                    return const _EmptySectionHint(
                      message:
                          'Nessun promemoria. Toccando "Vedi tutte" puoi crearne uno.',
                    );
                  }
                  return Column(
                    children: upcoming
                        .take(3)
                        .map((event) => Card(
                              child: ListTile(
                                leading: const Icon(
                                    Icons.notifications_none_outlined),
                                title: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => context.push(
                                    '/workspace/${workspace.id}/reminders'),
                              ),
                            ))
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                title: 'Memoria',
                onSeeAll: () =>
                    context.push('/workspace/${workspace.id}/memories'),
              ),
              const SizedBox(height: AppSpacing.sm),
              memoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) =>
                    const Text('Non è stato possibile caricare la memoria.'),
                data: (memories) => memories.isEmpty
                    ? const _EmptySectionHint(
                        message: 'Nessuna memoria. Toccando "Vedi tutte" '
                            'puoi aggiungerne una.',
                      )
                    : Column(
                        children: memories
                            .take(3)
                            .map((memory) => Card(
                                  child: ListTile(
                                    leading:
                                        const Icon(Icons.psychology_outlined),
                                    title: Text(
                                      memory.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => context.push(
                                        '/workspace/${workspace.id}/memories'),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Prossimamente', style: AppTypography.heading3),
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

/// Menu "azione rapida" del FAB (richiesta esplicita dell'utente: "migliorie
/// anche solo grafiche" ha incluso un modo più diretto di creare contenuti da
/// un Workspace). I Documenti restano esclusi: si caricano con un file
/// picker, non con una sheet di testo come le altre quattro.
void _showQuickActions(BuildContext context, String workspaceId) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('Nota'),
            onTap: () {
              Navigator.of(context).pop();
              showCreateEditNoteSheet(context, workspaceId: workspaceId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_task_outlined),
            title: const Text('Attività'),
            onTap: () {
              Navigator.of(context).pop();
              showCreateEditTaskSheet(context, workspaceId: workspaceId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Transazione'),
            onTap: () {
              Navigator.of(context).pop();
              showCreateEditTransactionSheet(context, workspaceId: workspaceId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_outlined),
            title: const Text('Promemoria'),
            onTap: () {
              Navigator.of(context).pop();
              showCreateReminderSheet(context, workspaceId: workspaceId);
            },
          ),
        ],
      ),
    ),
  );
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
