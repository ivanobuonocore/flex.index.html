import 'dart:async';
import 'dart:typed_data';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository({this.uploadResult, this.downloadUrlResult});

  final _controller = StreamController<List<Document>>.broadcast();
  Result<Document>? uploadResult;
  Result<String>? downloadUrlResult;
  Document? lastUploaded;
  String? lastDeletedId;

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
  }) async {
    final result = uploadResult ??
        const Result<Document>.err(
            ValidationFailure('Nessun risultato configurato.'));
    if (result.isOk) {
      lastUploaded = (result as Ok<Document>).value;
    }
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

  void dispose() => _controller.close();
}
