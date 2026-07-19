import 'package:pip_domain/pip_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Document', () {
    test('due document con stessi campi sono uguali per valore', () {
      final uploadedAt = DateTime.utc(2026, 1, 1);
      final a = Document(
        id: 'd1',
        workspaceId: 'w1',
        name: 'contratto.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        storagePath: 'w1/d1-contratto.pdf',
        hash: 'abc123',
        uploadedAt: uploadedAt,
      );
      final b = Document(
        id: 'd1',
        workspaceId: 'w1',
        name: 'contratto.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        storagePath: 'w1/d1-contratto.pdf',
        hash: 'abc123',
        uploadedAt: uploadedAt,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('deletedAt distingue due document altrimenti identici', () {
      final uploadedAt = DateTime.utc(2026, 1, 1);
      final active = Document(
        id: 'd1',
        workspaceId: 'w1',
        name: 'contratto.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        storagePath: 'w1/d1-contratto.pdf',
        hash: 'abc123',
        uploadedAt: uploadedAt,
      );
      final deleted = Document(
        id: 'd1',
        workspaceId: 'w1',
        name: 'contratto.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1024,
        storagePath: 'w1/d1-contratto.pdf',
        hash: 'abc123',
        uploadedAt: uploadedAt,
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      expect(active, isNot(equals(deleted)));
    });
  });
}
