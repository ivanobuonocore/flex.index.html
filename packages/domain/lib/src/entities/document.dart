/// File caricato dall'utente in un Workspace (Domain Model, entità Document).
final class Document {
  const Document({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.storagePath,
    required this.hash,
    required this.uploadedAt,
    this.chatId,
    this.deletedAt,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final String storagePath;

  /// Usato per la deduplicazione (Domain Model, nota tecnica: scope per-Workspace).
  final String hash;
  final DateTime uploadedAt;

  /// Chat da cui è stato caricato, se applicabile.
  final String? chatId;

  /// Soft delete (Domain Model, "Principi del modello"). L'oggetto in Storage
  /// non viene rimosso qui: la pulizia effettiva è un job separato, non
  /// ancora implementato.
  final DateTime? deletedAt;

  @override
  bool operator ==(Object other) =>
      other is Document &&
      other.id == id &&
      other.workspaceId == workspaceId &&
      other.name == name &&
      other.mimeType == mimeType &&
      other.sizeBytes == sizeBytes &&
      other.storagePath == storagePath &&
      other.hash == hash &&
      other.uploadedAt == uploadedAt &&
      other.chatId == chatId &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        workspaceId,
        name,
        mimeType,
        sizeBytes,
        storagePath,
        hash,
        uploadedAt,
        chatId,
        deletedAt,
      );

  @override
  String toString() =>
      'Document(id: $id, name: $name, workspaceId: $workspaceId)';
}
