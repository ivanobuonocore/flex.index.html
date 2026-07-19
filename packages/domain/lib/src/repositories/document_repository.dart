import 'dart:typed_data';

import 'package:pip_shared/pip_shared.dart';

import '../entities/document.dart';

/// Confine verso la persistenza dei Document (metadata + file), implementato
/// nel layer `data` di ogni app (Dependency Inversion — Engineering
/// Constitution, Articolo 4). `dart:typed_data` è parte del SDK Dart, non
/// introduce una dipendenza da Flutter o da un provider specifico.
abstract interface class DocumentRepository {
  /// Documenti del Workspace [workspaceId], ordinati per data di caricamento.
  Stream<List<Document>> watchDocuments(String workspaceId);

  /// [chatId]: valorizzato solo quando il documento è un allegato caricato
  /// dalla Chat (docs/database/README.md, sezione Documenti) — nullo per un
  /// upload dalla sezione Documenti del Workspace.
  Future<Result<Document>> uploadDocument({
    required String workspaceId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? chatId,
  });

  /// Soft delete (Domain Model, "Principi del modello"); il file resta in
  /// Storage.
  Future<Result<Unit>> deleteDocument(String documentId);

  /// URL temporaneo per aprire/scaricare il file (i bucket non sono pubblici).
  /// Prende l'intero [Document] — già disponibile lato UI dalla lista — invece
  /// di un id, evitando una lettura extra solo per recuperare `storagePath`.
  Future<Result<String>> getDownloadUrl(Document document);

  /// Legge un singolo Document per id — usato per renderizzare un allegato di
  /// Chat, di cui la UI conosce solo [Message.attachmentIds] (id soli), non
  /// l'oggetto completo.
  Future<Result<Document>> getDocument(String documentId);
}
