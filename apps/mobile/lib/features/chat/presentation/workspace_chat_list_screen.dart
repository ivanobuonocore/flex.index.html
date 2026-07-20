import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/chat_controller.dart';
import 'create_chat_sheet.dart';

/// Elenco delle Chat di un Workspace
/// (docs/product/06-information-architecture.md, "Menu Workspace").
/// Distinta dalla tab globale "Chat" (`chat_list_screen.dart`), che mostra
/// tutte le Chat dell'utente indipendentemente dal Workspace.
class WorkspaceChatListScreen extends ConsumerWidget {
  const WorkspaceChatListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateChatSheet(context, workspaceId: workspaceId),
        child: const Icon(Icons.add),
      ),
      body: chatsAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le chat.',
          onRetry: () => ref.invalidate(chatsProvider(workspaceId)),
        ),
        data: (chats) {
          if (chats.isEmpty) {
            return EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Nessuna chat ancora',
              message: 'Crea la prima chat di questo Workspace.',
              action: FilledButton(
                onPressed: () =>
                    showCreateChatSheet(context, workspaceId: workspaceId),
                child: const Text('Crea la prima chat'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(chat.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => context.push(
                    '/workspace/$workspaceId/chat/${chat.id}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
