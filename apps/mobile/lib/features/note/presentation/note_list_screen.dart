import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import '../../../shared/utils/undoable_delete.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../workspace/application/workspace_sharing_controller.dart';
import '../application/note_controller.dart';
import 'create_edit_note_sheet.dart';

/// Elenco completo delle Note di un Workspace
/// (docs/product/06-information-architecture.md, "Menu Workspace").
///
/// `Stateful` da questa slice (richiesta esplicita dell'utente: "tag sulle
/// Note resi visibili... filtro rapido per tag") per tenere il tag
/// selezionato per il filtro rapido — `null` = nessun filtro, l'elenco
/// completo di sempre.
class NoteListScreen extends ConsumerStatefulWidget {
  const NoteListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends ConsumerState<NoteListScreen> {
  String? _filterTag;

  // Rimozione ottimistica locale per "Annulla su eliminazioni" (integrazione
  // richiesta esplicitamente): filtra subito la nota scartata dall'elenco,
  // indipendentemente da quando (o se) il repository la cancella davvero.
  final _dismissedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider(widget.workspaceId));
    // Permessi granulari sui Workspace condivisi (integrazione richiesta
    // esplicitamente): `null` per un Workspace personale o per il
    // proprietario di uno condiviso, sempre accesso pieno in entrambi i
    // casi — solo un membro con ruolo `viewer` viene limitato qui.
    final isViewer = ref.watch(currentMemberRoleProvider(widget.workspaceId)) ==
        WorkspaceRole.viewer;

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Note')),
      floatingActionButton: isViewer
          ? null
          : FloatingActionButton(
              onPressed: () => showCreateEditNoteSheet(context,
                  workspaceId: widget.workspaceId),
              child: const Icon(Icons.add),
            ),
      body: notesAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare le note.',
          onRetry: () => ref.invalidate(notesProvider(widget.workspaceId)),
        ),
        data: (allNotes) {
          final notes = allNotes
              .where((n) => !_dismissedIds.contains(n.id))
              .toList(growable: false);
          if (notes.isEmpty) {
            return EmptyState(
              icon: Icons.sticky_note_2_outlined,
              color: AppColors.accentNote,
              title: 'Nessuna nota ancora',
              message: isViewer
                  ? 'Non ci sono ancora note in questo Workspace.'
                  : 'Crea la tua prima nota in questo Workspace.',
              action: isViewer
                  ? null
                  : FilledButton(
                      onPressed: () => showCreateEditNoteSheet(context,
                          workspaceId: widget.workspaceId),
                      child: const Text('Crea la prima nota'),
                    ),
            );
          }

          // Tutti i tag distinti tra le note di questo Workspace, per la
          // striscia di filtro rapido — non solo quelli della nota corrente.
          final allTags = <String>{for (final n in notes) ...n.tags}.toList()
            ..sort();
          final filterTag = _filterTag;
          final visibleNotes = filterTag == null
              ? notes
              : notes.where((n) => n.tags.contains(filterTag)).toList();

          return Column(
            children: [
              if (allTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: allTags.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final tag = allTags[index];
                        final isSelected = tag == filterTag;
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (_) => setState(
                            () => _filterTag = isSelected ? null : tag,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: visibleNotes.isEmpty
                    ? Center(
                        child: Text(
                          'Nessuna nota con questo tag.',
                          style: AppTypography.body.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: visibleNotes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final note = visibleNotes[index];
                          final card = Card(
                            child: ListTile(
                              leading: const Icon(Icons.sticky_note_2_outlined,
                                  color: AppColors.accentNote),
                              title: Text(note.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (note.content.isNotEmpty)
                                    Text(note.content,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  if (note.tags.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        for (final tag in note.tags)
                                          _TagPill(label: tag),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              onTap: isViewer
                                  ? null
                                  : () => showCreateEditNoteSheet(
                                        context,
                                        workspaceId: widget.workspaceId,
                                        note: note,
                                      ),
                            ),
                          );

                          if (isViewer) return card;

                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(context),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: AppRadii.standardRadius,
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) {
                              setState(() => _dismissedIds.add(note.id));
                              scheduleUndoableDelete(
                                context,
                                message: 'Nota eliminata.',
                                onConfirmed: () => ref
                                    .read(noteFormControllerProvider.notifier)
                                    .delete(note.id),
                                onUndo: () {
                                  if (mounted) {
                                    setState(
                                        () => _dismissedIds.remove(note.id));
                                  }
                                },
                              );
                            },
                            child: card,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Conferma prima di eliminare una nota (richiesta esplicita dell'utente:
  /// "conferma su swipe-to-delete per elementi non banali") — a differenza
  /// di una Transazione pending o un promemoria, il contenuto di una nota
  /// non è recuperabile con un tocco dopo lo swipe.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa nota?'),
        content: const Text('Il contenuto andrà perso.'),
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

/// Pillola compatta per un tag nell'anteprima di una Nota — solo lettura, a
/// differenza del [Chip] cancellabile nel form di creazione/modifica.
class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentNote.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.accentNote,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
