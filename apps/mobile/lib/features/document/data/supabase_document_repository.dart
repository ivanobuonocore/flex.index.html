import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Implementazione di [DocumentRepository] su Supabase Postgres + Storage.
/// L'isolamento tra Workspace è garantito dalle policy RLS di `documents` e
/// di `storage.objects` per il bucket `documents`
/// (`infrastructure/supabase/migrations`) — verificate manualmente, non solo
/// scritte per analogia.
class SupabaseDocumentRepository implements DocumentRepository {
  SupabaseDocumentRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _table = 'documents';
  static const _bucket = 'documents';

  /// Validità del link firmato per aprire un documento.
  static const _signedUrlExpirySeconds = 60;

  @override
  Stream<List<Document>> watchDocuments(String workspaceId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .order('uploaded_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => row['deleted_at'] == null)
              .map(parseDocumentRow)
              .toList(growable: false),
        );
  }

  @override
  Future<Result<Document>> uploadDocument({
    required String workspaceId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? chatId,
  }) async {
    if (fileName.trim().isEmpty) {
      return const Result.err(
          ValidationFailure('Il nome del file è obbligatorio.'));
    }

    // Univoco per upload: non serve un id generato lato client (niente
    // dipendenza da un package uuid) — la riga di metadata riceve il proprio
    // id da Postgres (gen_random_uuid()) all'insert.
    final sanitizedName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final storagePath =
        '$workspaceId/${DateTime.now().microsecondsSinceEpoch}_$sanitizedName';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                supabase.FileOptions(contentType: mimeType, upsert: false),
          );
    } catch (e) {
      return Result.err(UnexpectedFailure(
          'Non è stato possibile caricare il file.',
          cause: e));
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'workspace_id': workspaceId,
            'name': fileName.trim(),
            'mime_type': mimeType,
            'size_bytes': bytes.length,
            'storage_path': storagePath,
            'hash': sha256.convert(bytes).toString(),
            'chat_id': chatId,
          })
          .select()
          .single();
      return Result.ok(parseDocumentRow(row));
    } catch (e) {
      // Il file è già in Storage ma senza metadata: rimuovilo per non
      // lasciare un oggetto orfano (compensazione, non una transazione vera
      // — Storage e Postgres sono due sistemi separati).
      await _client.storage
          .from(_bucket)
          .remove([storagePath]).catchError((_) => <supabase.FileObject>[]);
      return Result.err(
        UnexpectedFailure('Non è stato possibile salvare il documento.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Unit>> deleteDocument(String documentId) async {
    try {
      await _client
          .from(_table)
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
              'id', documentId);
      return const Result.ok(unit);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile eliminare il documento.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<String>> getDownloadUrl(Document document) async {
    try {
      final url = await _client.storage
          .from(_bucket)
          .createSignedUrl(document.storagePath, _signedUrlExpirySeconds);
      return Result.ok(url);
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aprire il documento.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Document>> getDocument(String documentId) async {
    try {
      final row =
          await _client.from(_table).select().eq('id', documentId).single();
      return Result.ok(parseDocumentRow(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile leggere il documento.',
            cause: e),
      );
    }
  }

  @override
  Future<Result<Document>> updateTags({
    required String documentId,
    required List<String> tags,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .update({'tags': tags})
          .eq('id', documentId)
          .select()
          .single();
      return Result.ok(parseDocumentRow(row));
    } catch (e) {
      return Result.err(
        UnexpectedFailure('Non è stato possibile aggiornare i tag.', cause: e),
      );
    }
  }
}

/// Converte una riga di `documents` in un [Document] — funzione pura (non un
/// metodo privato) perché testabile senza mockare il client Supabase, stesso
/// motivo di `parseMessageRow` in `supabase_message_repository.dart`.
///
/// `tags` è letta con un cast tollerante a `null` invece che diretto: è stata
/// aggiunta da una migrazione additiva (Slice 1) più recente dello schema
/// originale di `documents` — se non ancora applicata al progetto Supabase
/// reale arriva `null`, non assente, e un cast diretto romperebbe il
/// caricamento dell'intera lista Documenti (stesso bug già corretto per
/// `messages.pending_transaction_ids`).
Document parseDocumentRow(Map<String, dynamic> row) {
  return Document(
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    name: row['name'] as String,
    mimeType: row['mime_type'] as String,
    sizeBytes: row['size_bytes'] as int,
    storagePath: row['storage_path'] as String,
    hash: row['hash'] as String,
    chatId: row['chat_id'] as String?,
    uploadedAt: DateTime.parse(row['uploaded_at'] as String),
    deletedAt: row['deleted_at'] != null
        ? DateTime.parse(row['deleted_at'] as String)
        : null,
    tags: (row['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
  );
}
