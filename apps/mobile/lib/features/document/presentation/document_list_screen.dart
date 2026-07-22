import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Documenti')),
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
        loading: () => const LoadingView(),
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
              title: 'Nessun documento ancora',
              message: _errorMessage ??
                  'Carica il tuo primo file in questo Workspace.',
              action: FilledButton(
                onPressed: isUploading ? null : _pickAndUpload,
                child: const Text('Carica il primo documento'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final document = documents[index];
              return Dismissible(
                key: ValueKey(document.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
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
                onDismissed: (_) {
                  setState(() => _dismissedIds.add(document.id));
                  ref
                      .read(documentFormControllerProvider.notifier)
                      .delete(document.id);
                },
                child: Card(
                  child: ListTile(
                    leading: Icon(_iconFor(document.mimeType),
                        color: AppColors.categoryDocumenti),
                    title: Text(document.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_formatSize(document.sizeBytes)),
                    onTap: () => _open(document),
                  ),
                ),
              );
            },
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
