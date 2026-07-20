import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';

/// Documenti di un Workspace, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final documentsProvider = StreamProvider.autoDispose
    .family<List<Document>, String>((ref, workspaceId) {
  return ref.watch(documentRepositoryProvider).watchDocuments(workspaceId);
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

  Future<Failure?> upload({
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
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> delete(String documentId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(documentRepositoryProvider).deleteDocument(documentId);
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
