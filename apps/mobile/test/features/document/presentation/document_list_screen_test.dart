import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/document/presentation/document_list_screen.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_document_repository.dart';
import '../../../support/fake_transaction_repository.dart';

/// Conferma su swipe-to-delete (richiesta esplicita dell'utente: "conferma
/// su swipe-to-delete per elementi non banali") — un Documento cancellato
/// non è recuperabile con un tocco dopo lo swipe.
void main() {
  const workspaceId = 'w1';
  final document = Document(
    id: 'd1',
    workspaceId: workspaceId,
    name: 'scontrino.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 1024,
    storagePath: 'w1/d1',
    hash: 'abc',
    uploadedAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    FakeDocumentRepository fakeRepository, {
    FakeTransactionRepository? fakeTransactionRepository,
  }) {
    final transactionRepository =
        fakeTransactionRepository ?? FakeTransactionRepository();
    addTearDown(transactionRepository.dispose);
    // Knowledge Graph "lite" (richiesta esplicita dell'utente):
    // `linkedDocumentIdsProvider` osservato dalla schermata dipende da
    // `transactionsProvider`, quindi va sempre sovrascritto qui anche per i
    // test che non testano quel comportamento — senza fake userebbe il vero
    // client Supabase, mai inizializzato nei test.
    transactionRepository.emit(const []);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(fakeRepository),
          transactionRepositoryProvider
              .overrideWithValue(transactionRepository),
        ],
        child: const MaterialApp(
          home: DocumentListScreen(workspaceId: workspaceId),
        ),
      ),
    );
  }

  testWidgets('scorrere un documento chiede conferma prima di cancellarlo',
      (tester) async {
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([document]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare questo documento?'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 'd1');
  });

  testWidgets('un documento con tag mostra le pillole e permette di filtrare',
      (tester) async {
    final taggedDocument = Document(
      id: 'd2',
      workspaceId: workspaceId,
      name: 'contratto.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2048,
      storagePath: 'w1/d2',
      hash: 'def',
      uploadedAt: DateTime.utc(2026, 1, 2),
      tags: const ['lavoro'],
    );
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([document, taggedDocument]);
    await tester.pumpAndSettle();

    expect(find.text('lavoro'), findsNWidgets(2)); // filtro + pillola

    await tester.tap(find.widgetWithText(FilterChip, 'lavoro'));
    await tester.pumpAndSettle();

    expect(find.text('scontrino.jpg'), findsNothing);
    expect(find.text('contratto.pdf'), findsOneWidget);
  });

  testWidgets('modificare i tag di un documento chiama updateTags',
      (tester) async {
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);
    fakeRepository.updateTagsResult = Result.ok(document);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([document]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.local_offer_outlined));
    await tester.pumpAndSettle();

    final tagField = find.widgetWithText(TextFormField, 'Aggiungi un tag');
    await tester.enterText(tagField, 'scontrini');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saveButton = find.text('Salva');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(fakeRepository.lastTagsUpdatedDocumentId, 'd1');
    expect(fakeRepository.lastTagsUpdatedTags, ['scontrini']);
  });

  testWidgets(
      'un documento referenziato da una Transazione mostra il badge '
      '"Collegato a una transazione" (Knowledge Graph "lite")', (tester) async {
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);
    final fakeTransactionRepository = FakeTransactionRepository();

    await pumpScreen(tester, fakeRepository,
        fakeTransactionRepository: fakeTransactionRepository);
    fakeRepository.emit([document]);
    fakeTransactionRepository.emit([
      Transaction(
        id: 'tx-1',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Spesa',
        amountCents: 500,
        occurredAt: DateTime.utc(2026, 1, 1),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 1, 1),
        documentId: document.id,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Collegato a una transazione'), findsOneWidget);
  });

  testWidgets(
      'un documento non referenziato da nessuna Transazione non mostra il '
      'badge', (tester) async {
    final fakeRepository = FakeDocumentRepository();
    addTearDown(fakeRepository.dispose);

    await pumpScreen(tester, fakeRepository);
    fakeRepository.emit([document]);
    await tester.pumpAndSettle();

    expect(find.text('Collegato a una transazione'), findsNothing);
  });
}
