import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/transaction/presentation/balance_overview_screen.dart';

import '../../../support/fake_transaction_repository.dart';
import '../../../support/fake_workspace_repository.dart';

// Duplicato dei nomi dei mesi usati (privati) in balance_overview_screen.dart:
// serve solo a costruire l'etichetta attesa nella tendina del mese.
const _italianMonths = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

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

    // L'hero del saldo + il grafico (redesign estetico 2.0) spingono
    // l'elenco delle transazioni confermate sotto la piega: va scorsa la
    // lista per trovarla, come farebbe l'utente.
    await tester.scrollUntilVisible(find.text('Stipendio'), 300);
    await tester.pumpAndSettle();

    // Solo la transazione del Bilancio personale conta: 1.000,00 € di
    // entrate, nessuna uscita — se il filtro non ci fosse, la spesa
    // condivisa (50,00 €) comparirebbe nell'elenco e nel saldo.
    expect(find.text('Stipendio'), findsOneWidget);
    expect(find.text('Spesa condivisa con Anna'), findsNothing);
    expect(find.textContaining('1000,00'), findsWidgets);
  });

  testWidgets('la tendina del mese filtra hero, grafico ed elenco confermate',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);

    final lastMonth = DateTime(now.year, now.month - 1, 15);
    final oldExpense = Transaction(
      id: 't-old',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Spesa del mese scorso',
      amountCents: 3000,
      occurredAt: lastMonth,
      status: TransactionStatus.confirmed,
      createdAt: lastMonth,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([personalIncome, oldExpense]);
    await tester.pumpAndSettle();

    // Di default (mese corrente) si vede la transazione di questo mese.
    await tester.scrollUntilVisible(find.text('Stipendio'), 300);
    expect(find.text('Stipendio'), findsOneWidget);

    // Torna in cima (la tendina del mese è nell'intestazione, scomparsa
    // scorrendo per il controllo sopra) prima di aprirla.
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();

    // Apre la tendina e sceglie il mese scorso.
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    final label = '${_italianMonths[lastMonth.month - 1]} ${lastMonth.year}';
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    // Ora il mese scorso è selezionato: la transazione di questo mese non
    // conta più nel totale/elenco, quella del mese scorso sì.
    await tester.scrollUntilVisible(find.text('Spesa del mese scorso'), 300);
    expect(find.text('Spesa del mese scorso'), findsOneWidget);
    expect(find.text('Stipendio'), findsNothing);
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
