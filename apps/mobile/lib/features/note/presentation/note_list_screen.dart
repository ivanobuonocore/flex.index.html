import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/note_controller.dart';
import 'create_edit_note_sheet.dart';

/// Elenco completo delle Note di un Workspace
/// (docs/product/06-information-architecture.md, "Menu Workspace").
class NoteListScreen extends ConsumerWidget {
  const NoteListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider(workspaceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showCreateEditNoteSheet(context, workspaceId: workspaceId),
        child: const Icon(Icons.add),
      ),
      body: notesAsync.when(
        loading: () => const LoadingView(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le note.',
          onRetry: () => ref.invalidate(notesProvider(workspaceId)),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'Nessuna nota ancora',
              message: 'Crea la tua prima nota in questo Workspace.',
              action: FilledButton(
                onPressed: () =>
                    showCreateEditNoteSheet(context, workspaceId: workspaceId),
                child: const Text('Crea la prima nota'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final note = notes[index];
              return Dismissible(
                key: ValueKey(note.id),
                direction: DismissDirection.endToStart,
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
                    .read(noteFormControllerProvider.notifier)
                    .delete(note.id),
                child: Card(
                  child: ListTile(
                    title: Text(note.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: note.content.isEmpty
                        ? null
                        : Text(note.content,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => showCreateEditNoteSheet(
                      context,
                      workspaceId: workspaceId,
                      note: note,
                    ),
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
