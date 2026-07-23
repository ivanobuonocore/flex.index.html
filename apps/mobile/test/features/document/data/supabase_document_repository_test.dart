import 'package:flutter_test/flutter_test.dart';
import 'package:pip_mobile/features/document/data/supabase_document_repository.dart';

/// `parseDocumentRow` è la parte con logica reale di `watchDocuments`:
/// separata in una funzione pura proprio per poterla testare senza mockare
/// il client Supabase (stesso motivo di `parseMessageRow` in
/// `supabase_message_repository.dart`).
void main() {
  group('parseDocumentRow', () {
    Map<String, dynamic> baseRow({Object? tags = const <String>[]}) => {
          'id': 'doc-1',
          'workspace_id': 'ws-1',
          'name': 'scontrino.jpg',
          'mime_type': 'image/jpeg',
          'size_bytes': 1024,
          'storage_path': 'ws-1/scontrino.jpg',
          'hash': 'abc123',
          'chat_id': null,
          'uploaded_at': '2026-07-22T10:00:00.000Z',
          'deleted_at': null,
          'tags': tags,
        };

    test('converte una riga completa in un Document', () {
      final document = parseDocumentRow(baseRow(tags: ['ricevute']));

      expect(document.id, 'doc-1');
      expect(document.tags, ['ricevute']);
    });

    test(
        'tags null (colonna aggiunta da una migrazione non ancora pushata) '
        'non fa fallire il parsing: lista vuota invece di un\'eccezione', () {
      final document = parseDocumentRow(baseRow(tags: null));

      expect(document.tags, isEmpty);
    });
  });
}
