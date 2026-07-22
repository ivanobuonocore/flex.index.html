import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/transaction/presentation/create_edit_transaction_sheet.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_transaction_repository.dart';

/// Richiesta esplicita dell'utente: "scontrino allegato alla Transazione".
/// Il flusso di scelta di un nuovo file (file_picker) richiederebbe di
/// mockare un canale di piattaforma non banale — questi test coprono la
/// visibilità del pulsante "Allega scontrino" quando non c'è ancora un
/// allegato e la rimozione di un allegato esistente (nessun file picker
/// coinvolto in quel percorso).
void main() {
  const workspaceId = 'w1';
  final transaction = Transaction(
    id: 't1',
    workspaceId: workspaceId,
    type: TransactionType.expense,
    description: 'Supermercato',
    amountCents: 3500,
    occurredAt: DateTime.utc(2026, 6, 15),
    status: TransactionStatus.confirmed,
    createdAt: DateTime.utc(2026, 6, 15),
  );
  final transactionWithReceipt = Transaction(
    id: 't2',
    workspaceId: workspaceId,
    type: TransactionType.expense,
    description: 'Supermercato',
    amountCents: 3500,
    occurredAt: DateTime.utc(2026, 6, 15),
    status: TransactionStatus.confirmed,
    createdAt: DateTime.utc(2026, 6, 15),
    documentId: 'd1',
  );

  Future<void> pumpSheet(
    WidgetTester tester,
    FakeTransactionRepository fakeRepository, {
    required Transaction transaction,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCreateEditTransactionSheet(context,
                  workspaceId: workspaceId, transaction: transaction),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'senza allegato mostra il pulsante "Allega scontrino" in modifica',
      (tester) async {
    final fakeRepository = FakeTransactionRepository();
    addTearDown(fakeRepository.dispose);

    await pumpSheet(tester, fakeRepository, transaction: transaction);

    expect(find.text('Allega scontrino'), findsOneWidget);
    expect(find.text('Scontrino allegato'), findsNothing);
  });

  testWidgets('in creazione (nessuna Transazione) non mostra la riga scontrino',
      (tester) async {
    final fakeRepository = FakeTransactionRepository();
    addTearDown(fakeRepository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCreateEditTransactionSheet(context,
                  workspaceId: workspaceId),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('Allega scontrino'), findsNothing);
    expect(find.text('Scontrino allegato'), findsNothing);
  });

  testWidgets('con un allegato esistente mostra "Scontrino allegato"',
      (tester) async {
    final fakeRepository = FakeTransactionRepository();
    addTearDown(fakeRepository.dispose);

    await pumpSheet(tester, fakeRepository,
        transaction: transactionWithReceipt);

    expect(find.text('Scontrino allegato'), findsOneWidget);
    expect(find.text('Allega scontrino'), findsNothing);
  });

  testWidgets('rimuovere l\'allegato chiama attachDocument con null',
      (tester) async {
    final fakeRepository = FakeTransactionRepository();
    addTearDown(fakeRepository.dispose);
    fakeRepository.attachDocumentResult = Result.ok(transaction);

    await pumpSheet(tester, fakeRepository,
        transaction: transactionWithReceipt);

    await tester.ensureVisible(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(fakeRepository.attachDocumentCalled, isTrue);
    expect(fakeRepository.lastAttachedTransactionId, 't2');
    expect(fakeRepository.lastAttachedDocumentId, isNull);
    expect(find.text('Allega scontrino'), findsOneWidget);
  });

  testWidgets(
      'aggiungere un tag e creare la transazione lo passa al repository',
      (tester) async {
    final fakeRepository = FakeTransactionRepository();
    addTearDown(fakeRepository.dispose);
    fakeRepository.createResult = Result.ok(transaction);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCreateEditTransactionSheet(context,
                  workspaceId: workspaceId),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrizione'), 'Benzina');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Importo (€)'), '20');
    final tagField = find.widgetWithText(TextFormField, 'Aggiungi un tag');
    await tester.ensureVisible(tagField);
    await tester.enterText(tagField, 'auto');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'auto'), findsOneWidget);

    final submitButton = find.text('Crea transazione');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(fakeRepository.lastCreatedTags, ['auto']);
  });

  testWidgets(
      'modificare una transazione esistente preserva i tag già presenti',
      (tester) async {
    final taggedTransaction = transaction.copyWith(tags: ['lavoro']);
    final fakeRepository = FakeTransactionRepository();
    addTearDown(fakeRepository.dispose);
    fakeRepository.updateResult = Result.ok(taggedTransaction);

    await pumpSheet(tester, fakeRepository, transaction: taggedTransaction);

    expect(find.widgetWithText(Chip, 'lavoro'), findsOneWidget);

    final submitButton = find.text('Salva');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(fakeRepository.lastUpdated?.tags, ['lavoro']);
  });
}
