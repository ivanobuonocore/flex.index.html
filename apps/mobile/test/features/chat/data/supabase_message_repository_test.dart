import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/features/chat/data/supabase_message_repository.dart';

/// `parseMessageRow` è la parte con logica reale di `watchMessages`:
/// separata in una funzione pura proprio per poterla testare senza mockare
/// il client Supabase/lo stream realtime (stesso motivo di
/// `parseReceiptExtractionResponse` in `supabase_transaction_repository.dart`).
///
/// Bug reale riprodotto qui (segnalato dall'utente: "la chat non va, mi esce
/// scritto il messaggio [che non è stato possibile caricare i messaggi]"):
/// `pending_transaction_ids` (colonna aggiunta con una migrazione additiva
/// più recente di `attachment_ids`/`source_references`) arriva `null` invece
/// che assente quando quella migrazione non è ancora stata pushata sul
/// progetto Supabase reale — un cast diretto (`as List<dynamic>`, non
/// `List<dynamic>?`) esplodeva dentro il `.map()` dello stream, facendo
/// fallire il caricamento dell'intera Chat per un problema operativo
/// (migrazione non applicata), non per un errore di rete o RLS reale.
void main() {
  group('parseMessageRow', () {
    Map<String, dynamic> baseRow({
      List<dynamic>? attachmentIds = const [],
      List<dynamic>? sourceReferences = const [],
      List<dynamic>? pendingTransactionIds = const [],
    }) =>
        {
          'id': 'msg-1',
          'chat_id': 'chat-1',
          'role': 'ai',
          'content': 'Ciao',
          'created_at': '2026-07-22T10:00:00.000Z',
          'attachment_ids': attachmentIds,
          'tokens_used': null,
          'source_references': sourceReferences,
          'pending_transaction_ids': pendingTransactionIds,
        };

    test('converte una riga completa in un Message', () {
      final message = parseMessageRow(baseRow(
        attachmentIds: ['doc-1'],
        sourceReferences: ['doc-2'],
        pendingTransactionIds: ['tx-1'],
      ));

      expect(message.id, 'msg-1');
      expect(message.chatId, 'chat-1');
      expect(message.role, MessageRole.ai);
      expect(message.content, 'Ciao');
      expect(message.attachmentIds, ['doc-1']);
      expect(message.sourceReferences, ['doc-2']);
      expect(message.pendingTransactionIds, ['tx-1']);
    });

    test(
        'pending_transaction_ids null (colonna aggiunta da una migrazione '
        'non ancora pushata) non fa fallire il parsing: lista vuota invece '
        'di un\'eccezione', () {
      final message = parseMessageRow(baseRow(pendingTransactionIds: null));

      expect(message.pendingTransactionIds, isEmpty);
    });

    test('attachment_ids null non fa fallire il parsing', () {
      final message = parseMessageRow(baseRow(attachmentIds: null));

      expect(message.attachmentIds, isEmpty);
    });

    test('source_references null non fa fallire il parsing', () {
      final message = parseMessageRow(baseRow(sourceReferences: null));

      expect(message.sourceReferences, isEmpty);
    });
  });
}
