import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/session_controller.dart';
import '../../workspace/application/workspace_category_meta.dart';
import '../../workspace/application/workspace_controller.dart';
import '../../workspace/presentation/widgets/section_preview.dart';
import '../../workspace/presentation/widgets/workspace_card.dart';
import '../application/chat_controller.dart';
import 'create_chat_sheet.dart';

/// Home dell'app (docs/product/06-information-architecture.md aggiornato —
/// richiesta esplicita dell'utente: "la funzione principale deve essere la
/// chat"). Sostituisce la vecchia coppia Today+Chat: saluto e Workspace
/// recenti (ex Today) restano in testa, seguiti da tutte le conversazioni
/// dell'utente, indipendentemente dal Workspace — punto di ingresso reale,
/// non solo un elenco di sola lettura come prima.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider(null));
    final workspacesAsync = ref.watch(workspacesProvider);
    final user = ref.watch(sessionControllerProvider).value;
    // Idempotente: crea solo le sezioni fisse mancanti (Fase 3, "Sezioni
    // fisse"). Nessuna UI propria: è un effetto collaterale silenzioso, il
    // risultato si vede quando workspacesProvider emette le nuove sezioni.
    ref.watch(workspaceBootstrapProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_greeting(user?.name))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateChatSheet(context),
        child: const Icon(Icons.add),
      ),
      body: chatsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le chat.',
          onRetry: () => ref.invalidate(chatsProvider(null)),
        ),
        data: (chats) {
          final workspaces = workspacesAsync.value ?? const [];
          final workspaceNames = <String, String>{
            for (final workspace in workspaces) workspace.id: workspace.name,
          };
          // Le sezioni fisse (Bilancio/Appuntamenti/Attività/Documenti) in
          // ordine fisso, non nell'ordine di creazione — l'utente deve
          // sempre trovarle nello stesso punto (docs/product/06, "Regola
          // fondamentale": mai un'app imprevedibile).
          final sections = <Workspace>[
            for (final category in SystemWorkspaceCategory.all)
              ...workspaces.where((w) => w.category == category),
          ];
          final freeWorkspaces = workspaces
              .where((w) => !WorkspaceCategoryMeta.isSystem(w.category))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (sections.isNotEmpty) ...[
                const Text('Sezioni', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sections.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return SizedBox(
                        width: 240,
                        child: WorkspaceCard(
                          workspace: section,
                          subtitle: SectionPreview(
                            category: section.category!,
                            workspaceId: section.id,
                          ),
                          onTap: () => context.push('/workspace/${section.id}'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (freeWorkspaces.isNotEmpty) ...[
                const Text('I tuoi Workspace', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: freeWorkspaces.take(5).length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) => SizedBox(
                      width: 240,
                      child: WorkspaceCard(
                        workspace: freeWorkspaces[index],
                        onTap: () => context
                            .push('/workspace/${freeWorkspaces[index].id}'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Text('Chat', style: AppTypography.heading3),
              const SizedBox(height: AppSpacing.sm),
              if (chats.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'Nessuna chat ancora. Tocca + per iniziarne una.',
                    style: AppTypography.body.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                )
              else
                for (final chat in chats) ...[
                  _ChatTile(
                    title: chat.title,
                    subtitle: chat.workspaceId == null
                        ? 'Chat privata'
                        : workspaceNames[chat.workspaceId] ?? 'Workspace',
                    onTap: () => context.push(
                      chat.workspaceId == null
                          ? '/chat/${chat.id}'
                          : '/workspace/${chat.workspaceId}/chat/${chat.id}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          );
        },
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

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
