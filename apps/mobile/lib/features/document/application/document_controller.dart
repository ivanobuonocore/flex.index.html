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
