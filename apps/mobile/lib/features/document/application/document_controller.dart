import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../transaction/application/transaction_controller.dart';

/// Documenti di un Workspace, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final documentsProvider = StreamProvider.autoDispose
    .family<List<Document>, String>((ref, workspaceId) {
  return ref.watch(documentRepositoryProvider).watchDocuments(workspaceId);
});

/// Id dei Documenti referenziati da almeno una Transazione di questo
/// Workspace (Knowledge Graph "lite" — richiesta esplicita dell'utente):
/// derivato interamente da [transactionsProvider], già la fonte di verità
/// per `Transaction.documentId` — nessuna nuova query, nessuna nuova
/// migrazione.
final linkedDocumentIdsProvider =
    Provider.autoDispose.family<Set<String>, String>((ref, workspaceId) {
  // `.asData?.value`, non `.value`: quest'ultimo rilancia l'eccezione
  // originale su uno stato di errore — un problema nel derivare i
  // collegamenti non deve mai far fallire l'intera lista Documenti.
  final transactions =
      ref.watch(transactionsProvider(workspaceId)).asData?.value ?? const [];
  return {
    for (final t in transactions)
      if (t.documentId != null) t.documentId!,
  };
});

/// URL firmato di un Document dato solo il suo id — usato per renderizzare un
/// allegato di Chat ([Message.attachmentIds]), di cui la UI non ha già
/// l'oggetto [Document] completo come invece accade nella lista Documenti.
final documentDownloadUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, documentId) async {
  final repository = ref.watch(documentRepositoryProvider);
  final documentResult = await repository.getDocument(documentId);
  if (documentResult.isErr) {
    throw (documentResult as Err<Document>).failure;
  }
  final urlResult =
      await repository.getDownloadUrl((documentResult as Ok<Document>).value);
  if (urlResult.isErr) {
    throw (urlResult as Err<String>).failure;
  }
  return (urlResult as Ok<String>).value;
});

final documentFormControllerProvider =
    AsyncNotifierProvider.autoDispose<DocumentFormController, void>(
  DocumentFormController.new,
);

class DocumentFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Ritorna il [Result] completo (non solo l'eventuale [Failure]): a
  /// differenza degli altri form controller di questa classe, chi chiama
  /// `upload` a volte ha bisogno dell'id del [Document] appena creato (es.
  /// per collegarlo a una Transazione come scontrino), non solo di sapere se
  /// l'operazione è riuscita.
  Future<Result<Document>> upload({
    required String workspaceId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(documentRepositoryProvider).uploadDocument(
          workspaceId: workspaceId,
          fileName: fileName,
          mimeType: mimeType,
          bytes: bytes,
        );
    state = const AsyncData(null);
    return result;
  }

  Future<Failure?> delete(String documentId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(documentRepositoryProvider).deleteDocument(documentId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// Sostituisce interamente i tag di un Document (integrazione richiesta
  /// esplicitamente), stesso pattern di [Note.tags].
  Future<Failure?> updateTags({
    required String documentId,
    required List<String> tags,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(documentRepositoryProvider).updateTags(
          documentId: documentId,
          tags: tags,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// Recupera un URL firmato e lo apre esternamente (browser/app associata).
  Future<Failure?> open(Document document) async {
    final result =
        await ref.read(documentRepositoryProvider).getDownloadUrl(document);
    if (result.isErr) {
      return (result as Err<String>).failure;
    }

    final url = (result as Ok<String>).value;
    final opened =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return opened
        ? null
        : const UnexpectedFailure('Non è stato possibile aprire il file.');
  }
}
