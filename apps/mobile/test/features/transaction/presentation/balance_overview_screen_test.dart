import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/transaction/presentation/balance_overview_screen.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_budget_repository.dart';
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
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
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
    await tester.scrollUntilVisible(find.text('Stipendio'), 300,
        scrollable: find.byType(Scrollable).first);
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
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

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
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([personalIncome, oldExpense]);
    await tester.pumpAndSettle();

    // Di default (mese corrente) si vede la transazione di questo mese.
    await tester.scrollUntilVisible(find.text('Stipendio'), 300,
        scrollable: find.byType(Scrollable).first);
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
    await tester.scrollUntilVisible(find.text('Spesa del mese scorso'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Spesa del mese scorso'), findsOneWidget);
    expect(find.text('Stipendio'), findsNothing);
  });

  testWidgets('la proiezione di fine mese compare solo per il mese corrente',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

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
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([personalIncome, oldExpense]);
    await tester.pumpAndSettle();

    // Mese corrente (default): la card di proiezione può comparire (dipende
    // dal giorno del mese reale, `null` solo il primo giorno) — qui si
    // verifica solo che non compaia MAI su uno storico, la proprietà che
    // conta davvero.
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    final label = '${_italianMonths[lastMonth.month - 1]} ${lastMonth.year}';
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(find.textContaining('Proiezione di fine mese'), findsNothing);
  });

  testWidgets('toccare la pillola Entrate apre il dettaglio per categoria',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final salary = Transaction(
      id: 't-salary',
      workspaceId: 'w-personal',
      type: TransactionType.income,
      description: 'Stipendio',
      amountCents: 100000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      category: TransactionCategory.stipendio,
    );
    final freelance = Transaction(
      id: 't-freelance',
      workspaceId: 'w-personal',
      type: TransactionType.income,
      description: 'Progetto extra',
      amountCents: 20000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      category: TransactionCategory.altro,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([salary, freelance]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrate'));
    await tester.pumpAndSettle();

    expect(find.text('Entrate per categoria'), findsOneWidget);
    expect(find.text('Stipendio'), findsOneWidget);
    expect(find.text('Altro'), findsOneWidget);
    expect(find.text('1000,00 €'), findsOneWidget);
    expect(find.text('200,00 €'), findsOneWidget);
  });

  testWidgets(
      'toccare una categoria nel dettaglio apre l\'andamento negli ultimi 6 mesi',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final salary = Transaction(
      id: 't-salary',
      workspaceId: 'w-personal',
      type: TransactionType.income,
      description: 'Stipendio',
      amountCents: 100000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      category: TransactionCategory.stipendio,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([salary]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrate'));
    await tester.pumpAndSettle();

    expect(find.text('Entrate per categoria'), findsOneWidget);

    await tester.tap(find.text('Stipendio'));
    await tester.pumpAndSettle();

    expect(find.text('Stipendio — ultimi 6 mesi'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets(
      'il pulsante "Categorie di spesa" mostra il dettaglio con la somma totale',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final groceries = Transaction(
      id: 't-groceries',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Spesa',
      amountCents: 5000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      category: TransactionCategory.alimentari,
    );
    final transport = Transaction(
      id: 't-transport',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Biglietto bus',
      amountCents: 1500,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      category: TransactionCategory.trasporti,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([groceries, transport]);
    fakeBudget.emit(const []);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categorie di spesa'));
    await tester.pumpAndSettle();

    expect(find.text('Totale: 65,00 €'), findsOneWidget);
    expect(find.text('Alimentari'), findsOneWidget);
    expect(find.text('Trasporti'), findsOneWidget);
  });

  testWidgets('una transazione confermata con tag mostra le pillole dei tag',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final tagged = Transaction(
      id: 't-tagged',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Benzina',
      amountCents: 2000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      tags: const ['auto', 'lavoro'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([tagged]);
    fakeBudget.emit(const []);
    await tester.pumpAndSettle();

    // La riga della transazione è sotto hero/grafico/budget: va scorsa in
    // vista prima che il finder la trovi (stesso pattern già usato altrove
    // per liste lunghe in una singola Scrollable).
    await tester.scrollUntilVisible(
      find.text('Benzina'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('auto'), findsOneWidget);
    expect(find.text('lavoro'), findsOneWidget);
  });

  testWidgets(
      'il campo di ricerca filtra le transazioni confermate per descrizione e tag',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final groceries = Transaction(
      id: 't-groceries',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Spesa supermercato',
      amountCents: 5000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      tags: const ['casa'],
    );
    final fuel = Transaction(
      id: 't-fuel',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Benzina',
      amountCents: 2000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      tags: const ['auto'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([groceries, fuel]);
    fakeBudget.emit(const []);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cerca per descrizione o tag…'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Spesa supermercato'), findsOneWidget);
    expect(find.text('Benzina'), findsOneWidget);

    // Filtro per descrizione.
    await tester.enterText(find.byType(TextField), 'benzina');
    await tester.pumpAndSettle();
    expect(find.text('Spesa supermercato'), findsNothing);
    expect(find.text('Benzina'), findsOneWidget);

    // Filtro per tag: nessuna transazione con descrizione "cinema" ma una
    // con tag "casa".
    await tester.enterText(find.byType(TextField), 'casa');
    await tester.pumpAndSettle();
    expect(find.text('Spesa supermercato'), findsOneWidget);
    expect(find.text('Benzina'), findsNothing);

    // Nessun risultato.
    await tester.enterText(find.byType(TextField), 'inesistente');
    await tester.pumpAndSettle();
    expect(find.text('Spesa supermercato'), findsNothing);
    expect(find.text('Benzina'), findsNothing);
    expect(find.text('Nessun risultato per "inesistente".'), findsOneWidget);
  });

  testWidgets(
      'il pulsante Condividi riepilogo apre il foglio con saldo e copia negli appunti',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    // flutter_test non mocka Clipboard.setData di default (a differenza di
    // altri canali comuni): senza questo handler la chiamata reale fallisce
    // con MissingPluginException nell'ambiente di test.
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(() => TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([personalIncome]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();

    expect(find.textContaining('Riepilogo Bilancio'), findsWidgets);
    expect(find.textContaining('Saldo: +1000,00 €'), findsOneWidget);
    expect(find.text('Copia negli appunti'), findsOneWidget);
    expect(find.text('Invia via email'), findsOneWidget);

    // Un singolo pump (non pumpAndSettle): lo SnackBar resta visibile per
    // qualche secondo, pumpAndSettle farebbe avanzare il tempo fittizio del
    // test fino a farlo scomparire di nuovo prima del controllo sotto.
    await tester.tap(find.text('Copia negli appunti'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Riepilogo copiato negli appunti.'), findsOneWidget);
  });

  testWidgets('se restano solo transazioni condivise mostra lo stato vuoto',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([sharedWorkspace]);
    fakeTransaction.emit([sharedExpense]);
    await tester.pumpAndSettle();

    expect(find.text('Nessuna transazione ancora'), findsOneWidget);
  });

  testWidgets(
      'un budget superato mostra "Budget superato" nella pillola di categoria',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final groceries = Transaction(
      id: 't-groceries',
      workspaceId: 'w-personal',
      type: TransactionType.expense,
      description: 'Supermercato',
      amountCents: 40000,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
      category: TransactionCategory.alimentari,
    );
    final budget = CategoryBudget(
      id: 'b1',
      category: TransactionCategory.alimentari,
      monthlyLimitCents: 30000,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([groceries]);
    // _BudgetSection non esiste nell'albero finché transazioni/Workspace non
    // hanno dati (gate su transactionsAsync.when): un pump() intermedio fa
    // montare la ListView. Non basta più da solo (redesign con grafico
    // "andamento ultimi 6 mesi", più in alto nella ListView): _BudgetSection
    // ora ricade oltre il cacheExtent di default finché non si scorre, quindi
    // resta fuori dall'albero e non si sottoscrive a budgetsProvider in
    // tempo — uno scroll esplicito prima dell'emit lo porta dentro
    // cacheExtent così la sottoscrizione parte PRIMA dell'emissione sotto
    // (altrimenti, essendo _controller un broadcast StreamController,
    // l'emissione andrebbe persa: nessun listener ancora, nessun replay).
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    fakeBudget.emit([budget]);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Budget per categoria'), 300,
        scrollable: find.byType(Scrollable).first);
    // "Alimentari" compare due volte: nel budget e nel badge categoria della
    // transazione confermata elencata più sotto nella stessa schermata.
    expect(find.text('Alimentari'), findsWidgets);
    expect(find.text('400,00 € / 300,00 €'), findsOneWidget);
    expect(find.text('Budget superato'), findsOneWidget);
  });

  testWidgets('il pulsante "Aggiungi" imposta un nuovo budget per categoria',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final budget = CategoryBudget(
      id: 'b1',
      category: TransactionCategory.alimentari,
      monthlyLimitCents: 30000,
      updatedAt: now,
    );
    fakeBudget.setResult = Result.ok(budget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([personalIncome]);
    // Vedi commento nel test precedente: pump() + scroll intermedi prima
    // dell'emit di fakeBudget, altrimenti l'emissione sul broadcast stream va
    // persa (_BudgetSection non ancora dentro cacheExtent).
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pump();
    fakeBudget.emit(const []);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.text('Imposta un budget per categoria'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Imposta un budget per categoria'));
    await tester.pumpAndSettle();

    // La schermata sotto ha ora un proprio TextField di ricerca (Bilancio,
    // ricerca nelle Transazioni confermate): il finder va ristretto al
    // TextField dentro l'AlertDialog per restare univoco.
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '300',
    );
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(fakeBudget.lastSetCategory, TransactionCategory.alimentari);
    expect(fakeBudget.lastSetMonthlyLimitCents, 30000);
  });

  testWidgets(
      'mostra il grafico "Andamento ultimi 6 mesi" e il badge vs mese scorso',
      (tester) async {
    final fakeTransaction = FakeTransactionRepository();
    final fakeWorkspace = FakeWorkspaceRepository();
    final fakeBudget = FakeBudgetRepository();
    addTearDown(fakeTransaction.dispose);
    addTearDown(fakeWorkspace.dispose);
    addTearDown(fakeBudget.dispose);

    final lastMonth = DateTime(now.year, now.month - 1, 15);
    // Mese scorso: 500,00 € di entrate. Mese corrente: 1.000,00 € (vedi
    // personalIncome) → +100% rispetto al mese scorso.
    final lastMonthIncome = Transaction(
      id: 't-last-month',
      workspaceId: 'w-personal',
      type: TransactionType.income,
      description: 'Stipendio mese scorso',
      amountCents: 50000,
      occurredAt: lastMonth,
      status: TransactionStatus.confirmed,
      createdAt: lastMonth,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTransaction),
          workspaceRepositoryProvider.overrideWithValue(fakeWorkspace),
          budgetRepositoryProvider.overrideWithValue(fakeBudget),
        ],
        child: const MaterialApp(home: BalanceOverviewScreen()),
      ),
    );

    fakeWorkspace.emit([personalWorkspace]);
    fakeTransaction.emit([personalIncome, lastMonthIncome]);
    await tester.pumpAndSettle();

    expect(find.textContaining('vs mese scorso'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Andamento ultimi 6 mesi'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Andamento ultimi 6 mesi'), findsOneWidget);
  });
}
