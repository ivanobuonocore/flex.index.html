import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../shared/utils/undoable_delete.dart';
import '../../../shared/widgets/document_thumbnail.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../application/document_controller.dart';

/// Elenco completo dei Documenti di un Workspace
/// (docs/product/06-information-architecture.md, "Documenti").
class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  String? _errorMessage;

  // Filtro rapido per tag (richiesta esplicita dell'utente, integrazione
  // confermata) — stesso pattern già usato in `note_list_screen.dart`.
  String? _filterTag;

  /// Rimozione ottimistica locale (Dismissible, non `documentsProvider`):
  /// questa schermata osserva `documentFormControllerProvider` per lo
  /// spinner di upload sul FAB — `delete()` usa lo stesso controller, quindi
  /// il giro `AsyncLoading`→`AsyncData` di un'eliminazione ricostruisce
  /// anche questa lista mentre il `Dismissible` sta ancora animando l'uscita,
  /// reinserendo la stessa riga prima che il repository abbia effettivamente
  /// rimosso il documento — Flutter la segnala con "A dismissed Dismissible
  /// widget is still part of the tree" (trovato aggiungendo la conferma su
  /// swipe, che sposta l'eliminazione oltre un frame in più). Filtrare qui
  /// gli id appena scorsi evita che la riga ricompaia in quel frame.
  final _dismissedIds = <String>{};

  Future<void> _pickAndUpload() async {
    setState(() => _errorMessage = null);

    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    final uploadResult =
        await ref.read(documentFormControllerProvider.notifier).upload(
              workspaceId: widget.workspaceId,
              fileName: file.name,
              mimeType: _guessMimeType(file.extension),
              bytes: file.bytes!,
            );

    if (!mounted) return;
    if (uploadResult.isErr) {
      final failure = (uploadResult as Err<Document>).failure;
      setState(() => _errorMessage = failure.message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _open(Document document) async {
    final failure =
        await ref.read(documentFormControllerProvider.notifier).open(document);
    if (!mounted || failure == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider(widget.workspaceId));
    final isUploading = ref.watch(documentFormControllerProvider).isLoading;
    // Knowledge Graph "lite" (richiesta esplicita dell'utente): quali
    // Documenti di questo Workspace sono referenziati da una Transazione
    // (es. uno scontrino allegato) — derivato, nessuna nuova query.
    final linkedDocumentIds =
        ref.watch(linkedDocumentIdsProvider(widget.workspaceId));

    return Scaffold(
      appBar: const GradientAppBar(title: Text('Documenti')),
      floatingActionButton: FloatingActionButton(
        onPressed: isUploading ? null : _pickAndUpload,
        child: isUploading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file_outlined),
      ),
      body: documentsAsync.when(
        loading: () => const SkeletonList(),
        error: (error, stackTrace) => ErrorView(
          message: 'Non è stato possibile caricare i documenti.',
          onRetry: () => ref.invalidate(documentsProvider(widget.workspaceId)),
        ),
        data: (allDocuments) {
          final documents = allDocuments
              .where((d) => !_dismissedIds.contains(d.id))
              .toList(growable: false);
          if (documents.isEmpty) {
            return EmptyState(
              icon: Icons.upload_file_outlined,
              color: AppColors.categoryDocumenti,
              title: 'Nessun documento ancora',
              message: _errorMessage ??
                  'Carica il tuo primo file in questo Workspace.',
              action: FilledButton(
                onPressed: isUploading ? null : _pickAndUpload,
                child: const Text('Carica il primo documento'),
              ),
            );
          }

          // Tutti i tag distinti tra i documenti di questo Workspace, per la
          // striscia di filtro rapido (stesso pattern di `note_list_screen.dart`).
          final allTags =
              <String>{for (final d in documents) ...d.tags}.toList()..sort();
          final filterTag = _filterTag;
          final visibleDocuments = filterTag == null
              ? documents
              : documents.where((d) => d.tags.contains(filterTag)).toList();

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
                child: visibleDocuments.isEmpty
                    ? Center(
                        child: Text(
                          'Nessun documento con questo tag.',
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
                        itemCount: visibleDocuments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final document = visibleDocuments[index];
                          return Dismissible(
                            key: ValueKey(document.id),
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
                              setState(() => _dismissedIds.add(document.id));
                              // "Annulla" su eliminazioni (integrazione
                              // richiesta esplicitamente): la cancellazione
                              // reale è posticipata di qualche secondo, non
                              // immediata — l'id resta comunque filtrato
                              // dalla lista per tutta l'attesa.
                              scheduleUndoableDelete(
                                context,
                                message: 'Documento eliminato.',
                                onConfirmed: () => ref
                                    .read(
                                        documentFormControllerProvider.notifier)
                                    .delete(document.id),
                                onUndo: () {
                                  if (mounted) {
                                    setState(() =>
                                        _dismissedIds.remove(document.id));
                                  }
                                },
                              );
                            },
                            child: Card(
                              child: ListTile(
                                leading: document.mimeType.startsWith('image/')
                                    ? DocumentThumbnail(
                                        documentId: document.id,
                                        height: 48,
                                        width: 48,
                                      )
                                    : Icon(_iconFor(document.mimeType),
                                        color: AppColors.categoryDocumenti),
                                title: Text(document.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_formatSize(document.sizeBytes)),
                                    if (linkedDocumentIds
                                        .contains(document.id)) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.receipt_long_outlined,
                                              size: 14,
                                              color:
                                                  AppColors.categoryBilancio),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Collegato a una transazione',
                                            style: AppTypography.caption
                                                .copyWith(
                                                    color: AppColors
                                                        .categoryBilancio),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (document.tags.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Wrap(
                                        spacing: AppSpacing.xs,
                                        runSpacing: AppSpacing.xs,
                                        children: [
                                          for (final tag in document.tags)
                                            _DocumentTagPill(label: tag),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.local_offer_outlined),
                                  tooltip: 'Modifica tag',
                                  onPressed: () => _showEditTagsSheet(
                                      context, ref, document),
                                ),
                                onTap: () => _open(document),
                              ),
                            ),
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

  /// Conferma prima di eliminare un documento (richiesta esplicita
  /// dell'utente: "conferma su swipe-to-delete per elementi non banali") —
  /// il file caricato non è recuperabile con un tocco dopo lo swipe.
  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questo documento?'),
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

  IconData _iconFor(String mimeType) {
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word')) return Icons.description_outlined;
    if (mimeType.contains('sheet') || mimeType.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mimeType.startsWith('text/')) return Icons.article_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// `file_picker` non espone il MIME type: lo si deduce dall'estensione
  /// (docs/product/06-information-architecture.md, "Documenti" — formati
  /// supportati). Estensioni non riconosciute restano `application/octet-stream`.
  String _guessMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Pillola compatta per un tag di Documento — solo lettura, stesso ruolo di
/// `_TagPill` in `note_list_screen.dart`.
class _DocumentTagPill extends StatelessWidget {
  const _DocumentTagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.categoryDocumenti.withOpacity(0.14),
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.categoryDocumenti,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Modifica dei tag di un Documento già caricato (integrazione richiesta
/// esplicitamente) — un Document non ha un form di modifica generico (nome e
/// file restano immutabili), quindi i tag hanno un piccolo foglio dedicato
/// invece di riusare una sheet di creazione/modifica come Note/Transazioni.
void _showEditTagsSheet(
  BuildContext context,
  WidgetRef ref,
  Document document,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
    ),
    builder: (context) => _EditTagsSheet(document: document),
  );
}

class _EditTagsSheet extends ConsumerStatefulWidget {
  const _EditTagsSheet({required this.document});

  final Document document;

  @override
  ConsumerState<_EditTagsSheet> createState() => _EditTagsSheetState();
}

class _EditTagsSheetState extends ConsumerState<_EditTagsSheet> {
  final _tagInputController = TextEditingController();
  late List<String> _tags = List.of(widget.document.tags);
  String? _errorMessage;

  @override
  void dispose() {
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTagFromInput() {
    final raw =
        _tagInputController.text.replaceAll(',', '').trim().toLowerCase();
    _tagInputController.clear();
    if (raw.isEmpty || _tags.contains(raw)) return;
    setState(() => _tags = [..._tags, raw]);
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    _addTagFromInput();

    final failure =
        await ref.read(documentFormControllerProvider.notifier).updateTags(
              documentId: widget.document.id,
              tags: _tags,
            );

    if (!mounted) return;
    if (failure != null) {
      setState(() => _errorMessage = failure.message);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(documentFormControllerProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tag di ${widget.document.name}', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _tagInputController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Aggiungi un tag',
              helperText: 'Invio o virgola per aggiungerlo',
            ),
            onFieldSubmitted: (_) => _addTagFromInput(),
            onChanged: (value) {
              if (value.endsWith(',')) _addTagFromInput();
            },
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final tag in _tags)
                  Chip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                  ),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
