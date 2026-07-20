import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/transaction/presentation/balance_overview_screen.dart';

import '../../../support/fake_transaction_repository.dart';
import '../../../support/fake_workspace_repository.dart';

/// Fase 3, "Bilancio condiviso" — richiesta esplicita dell'utente: due
/// Bilanci separati, uno personale e uno condiviso, non un unico totale che
/// li confonda. Il Bilancio globale (questa schermata, `transactionsProvider
/// (null)`) non filtra per Workspace lato applicazione: senza un filtro
/// esplicito sul Workspace di ogni transazione, quelle di un Bilancio
/// condiviso finirebbero comunque qui, mischiate col totale personale.
void main() {
  final personalWorkspace = Workspace(
    id: 'w-personal',
    ownerId: 'u1',
    name: 'Bilancio',
    icon: 'folder',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
    category: SystemWorkspaceCategory.bilancio,
  );
  final sharedWorkspace = Workspace(
    id: 'w-shared',
    ownerId: 'u1',
    name: 'Bilancio con Anna',
    icon: 'group',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
    category: sharedBalanceCategory,
  );

  final now = DateTime.now();
  final personalIncome = Transaction(
    id: 't-personal',
    workspaceId: 'w-personal',
    type: TransactionType.income,
    description: 'Stipendio',
    amountCents: 100000,
    occurredAt: now,
    status: TransactionStatus.confirmed,
    createdAt: now,
  );
  final sharedExpense = Transaction(
    id: 't-shared',
    workspaceId: 'w-shared',
    type: TransactionType.expense,
    description: 'Spesa condivisa con Anna',
    amountCents: 5000,
    occurredAt: now,
    status: TransactionStatus.confirmed,
    createdAt: now,
  );

  testWidgets(
      'esclude le transazioni di un Bilancio condiviso dal totale globale',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace, sharedWorkspace]);
    fakeTransaction.emit([personalIncome, sharedExpense]);
    await tester.pumpAndSettle();

    // Solo la transazione del Bilancio personale conta: 1.000,00 € di
    // entrate, nessuna uscita — se il filtro non ci fosse, la spesa
    // condivisa (50,00 €) comparirebbe nell'elenco e nel saldo.
    expect(find.text('Stipendio'), findsOneWidget);
    expect(find.text('Spesa condivisa con Anna'), findsNothing);
    expect(find.textContaining('1000,00'), findsWidgets);
  });

  testWidgets('se restano solo transazioni condivise mostra lo stato vuoto',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([sharedWorkspace]);
    fakeTransaction.emit([sharedExpense]);
    await tester.pumpAndSettle();

    expect(find.text('Nessuna transazione ancora'), findsOneWidget);
  });
}
