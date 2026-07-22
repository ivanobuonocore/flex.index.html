import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/recurring_transaction/presentation/recurring_transaction_list_sheet.dart';

import '../../../support/fake_recurring_transaction_repository.dart';

void main() {
  const workspaceId = 'w1';
  final template = RecurringTransactionTemplate(
    id: 'r1',
    workspaceId: workspaceId,
    type: TransactionType.expense,
    description: 'Netflix',
    amountCents: 1599,
    category: TransactionCategory.svago,
    frequency: RecurrenceFrequency.monthly,
    nextOccurrenceAt: DateTime.utc(2026, 8, 1),
    anchorDay: 1,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  Future<void> pumpAndOpenSheet(
    WidgetTester tester,
    FakeRecurringTransactionRepository fakeRepository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringTransactionRepositoryProvider
              .overrideWithValue(fakeRepository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRecurringTransactionListSheet(context,
                  workspaceId: workspaceId),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    // Non pumpAndSettle: finché recurringTransactionsProvider non ha ancora
    // dati, il foglio mostra un CircularProgressIndicator (animazione
    // indeterminata) che non si "assesta" mai — un pump delimitato basta a
    // far completare l'animazione di apertura del foglio.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('mostra il messaggio vuoto senza ricorrenti', (tester) async {
    final fakeRepository = FakeRecurringTransactionRepository();
    addTearDown(fakeRepository.dispose);

    await pumpAndOpenSheet(tester, fakeRepository);
    fakeRepository.emit(const []);
    await tester.pumpAndSettle();

    expect(find.text('Nessuna spesa o entrata ricorrente ancora.'),
        findsOneWidget);
  });

  testWidgets('mostra la descrizione e la frequenza di ogni ricorrente',
      (tester) async {
    final fakeRepository = FakeRecurringTransactionRepository();
    addTearDown(fakeRepository.dispose);

    await pumpAndOpenSheet(tester, fakeRepository);
    fakeRepository.emit([template]);
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.textContaining('Ogni mese'), findsOneWidget);
  });

  testWidgets('scorrere una ricorrente chiede conferma prima di cancellarla',
      (tester) async {
    final fakeRepository = FakeRecurringTransactionRepository();
    addTearDown(fakeRepository.dispose);

    await pumpAndOpenSheet(tester, fakeRepository);
    fakeRepository.emit([template]);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare questa ricorrenza?'), findsOneWidget);
    expect(fakeRepository.lastDeletedId, isNull);

    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(fakeRepository.lastDeletedId, 'r1');
  });
}
