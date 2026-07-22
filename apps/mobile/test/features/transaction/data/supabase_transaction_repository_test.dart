import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/features/transaction/data/supabase_transaction_repository.dart';

/// `parseReceiptExtractionResponse` è la parte con logica reale di
/// `extractReceiptData` (OCR sugli scontrini — integrazione richiesta
/// esplicitamente): separata in una funzione pura proprio per poterla
/// testare senza mockare il client Supabase/la Edge Function `ai-chat`
/// (nessun test in questo progetto mocka quel livello — vedi gli altri
/// `Supabase*Repository`, mai esercitati direttamente nei test).
void main() {
  group('parseReceiptExtractionResponse', () {
    test('converte una risposta valida in un ReceiptExtraction', () {
      final extraction = parseReceiptExtractionResponse({
        'ok': true,
        'result': {
          'type': 'expense',
          'description': 'Supermercato Coop',
          'amountCents': 4599,
          'occurredAt': '2026-07-20',
          'category': 'alimentari',
        },
      });

      expect(
        extraction,
        ReceiptExtraction(
          type: TransactionType.expense,
          description: 'Supermercato Coop',
          amountCents: 4599,
          occurredAt: DateTime(2026, 7, 20),
          category: TransactionCategory.alimentari,
        ),
      );
    });

    test('result null (foto non leggibile come scontrino) ritorna null', () {
      final extraction = parseReceiptExtractionResponse({
        'ok': true,
        'result': null,
      });

      expect(extraction, isNull);
    });

    test('responseData null ritorna null', () {
      expect(parseReceiptExtractionResponse(null), isNull);
    });

    test(
        'amountCents 0 (scontrino non riconosciuto, vedi system prompt) '
        'ritorna null invece di un importo inventato', () {
      final extraction = parseReceiptExtractionResponse({
        'result': {
          'type': 'expense',
          'description': 'Non leggibile',
          'amountCents': 0,
          'occurredAt': '2026-07-20',
          'category': 'altro',
        },
      });

      expect(extraction, isNull);
    });

    test('descrizione vuota ritorna null', () {
      final extraction = parseReceiptExtractionResponse({
        'result': {
          'type': 'expense',
          'description': '',
          'amountCents': 1000,
          'occurredAt': '2026-07-20',
          'category': 'altro',
        },
      });

      expect(extraction, isNull);
    });

    test('data non parsabile ritorna null', () {
      final extraction = parseReceiptExtractionResponse({
        'result': {
          'type': 'expense',
          'description': 'Bar',
          'amountCents': 250,
          'occurredAt': 'non-una-data',
          'category': 'svago',
        },
      });

      expect(extraction, isNull);
    });

    test('categoria sconosciuta ricade su altro invece di fallire', () {
      final extraction = parseReceiptExtractionResponse({
        'result': {
          'type': 'expense',
          'description': 'Bar',
          'amountCents': 250,
          'occurredAt': '2026-07-20',
          'category': 'categoria-inventata',
        },
      });

      expect(extraction?.category, TransactionCategory.altro);
    });

    test(
        'type diverso da "income" ricade su expense (uno scontrino non è '
        'mai un\'entrata)', () {
      final extraction = parseReceiptExtractionResponse({
        'result': {
          'type': 'qualcosa-altro',
          'description': 'Bar',
          'amountCents': 250,
          'occurredAt': '2026-07-20',
          'category': 'svago',
        },
      });

      expect(extraction?.type, TransactionType.expense);
    });
  });

  group('parseTransactionRow', () {
    Map<String, dynamic> baseRow({Object? tags = const <String>[]}) => {
          'id': 'tx-1',
          'workspace_id': 'ws-1',
          'chat_id': null,
          'type': 'expense',
          'description': 'Bar',
          'amount_cents': 250,
          'currency': 'EUR',
          'occurred_at': '2026-07-22T10:00:00.000Z',
          'status': 'confirmed',
          'created_by_ai': false,
          'created_at': '2026-07-22T10:00:00.000Z',
          'deleted_at': null,
          'category': 'svago',
          'document_id': null,
          'tags': tags,
        };

    test('converte una riga completa in una Transaction', () {
      final transaction = parseTransactionRow(baseRow(tags: ['weekend']));

      expect(transaction.id, 'tx-1');
      expect(transaction.tags, ['weekend']);
    });

    test(
        'tags null (colonna aggiunta da una migrazione non ancora pushata) '
        'non fa fallire il parsing: lista vuota invece di un\'eccezione', () {
      final transaction = parseTransactionRow(baseRow(tags: null));

      expect(transaction.tags, isEmpty);
    });
  });
}
