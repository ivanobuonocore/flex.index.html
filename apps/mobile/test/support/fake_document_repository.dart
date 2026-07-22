import 'dart:async';
import 'dart:typed_data';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository(
      {this.uploadResult,
      this.downloadUrlResult,
      this.getDocumentResult,
      this.updateTagsResult});

  final _controller = StreamController<List<Document>>.broadcast();
  Result<Document>? uploadResult;
  Result<String>? downloadUrlResult;
  Result<Document>? getDocumentResult;
  Result<Document>? updateTagsResult;
  Document? lastUploaded;
  String? lastUploadedChatId;
  String? lastDeletedId;
  String? lastTagsUpdatedDocumentId;
  List<String>? lastTagsUpdatedTags;

  void emit(List<Document> documents) => _controller.add(documents);

  @override
  Stream<List<Document>> watchDocuments(String workspaceId) =>
      _controller.stream;

  @override
  Future<Result<Document>> uploadDocument({
    required String workspaceId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? chatId,
  }) async {
    final result = uploadResult ??
        const Result<Document>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastUploaded = (result as Ok<Document>).value;
    }
    lastUploadedChatId = chatId;
    return result;
  }

  @override
  Future<Result<Unit>> deleteDocument(String documentId) async {
    lastDeletedId = documentId;
    return const Result.ok(unit);
  }

  @override
  Future<Result<String>> getDownloadUrl(Document document) async {
    return downloadUrlResult ??
        const Result.err(UnexpectedFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Document>> getDocument(String documentId) async {
    return getDocumentResult ??
        const Result.err(UnexpectedFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Document>> updateTags({
    required String documentId,
    required List<String> tags,
  }) async {
    lastTagsUpdatedDocumentId = documentId;
    lastTagsUpdatedTags = tags;
    return updateTagsResult ??
        const Result.err(UnexpectedFailure('Nessun risultato configurato.'));
  }

  void dispose() => _controller.close();
}
