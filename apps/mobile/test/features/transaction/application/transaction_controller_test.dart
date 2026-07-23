import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/budget/application/budget_controller.dart';
import 'package:pip_mobile/features/transaction/application/transaction_controller.dart';
import 'package:pip_mobile/features/workspace/application/workspace_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_budget_repository.dart';
import '../../../support/fake_transaction_repository.dart';
import '../../../support/fake_workspace_repository.dart';

void main() {
  const workspaceId = 'w1';
  final expense = Transaction(
    id: 'e1',
    workspaceId: workspaceId,
    type: TransactionType.expense,
    description: 'Barbiere',
    amountCents: 2300,
    occurredAt: DateTime.utc(2026, 6, 15),
    status: TransactionStatus.confirmed,
    createdAt: DateTime.utc(2026, 6, 15),
  );

  final workspace = Workspace(
    id: workspaceId,
    ownerId: 'u1',
    name: 'Personale',
    icon: '💶',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeTransactionRepository fakeRepository;
  late FakeWorkspaceRepository fakeWorkspaceRepository;
  late FakeBudgetRepository fakeBudgetRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeTransactionRepository();
    fakeWorkspaceRepository = FakeWorkspaceRepository();
    fakeBudgetRepository = FakeBudgetRepository();
    container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(fakeRepository),
        workspaceRepositoryProvider.overrideWithValue(fakeWorkspaceRepository),
        budgetRepositoryProvider.overrideWithValue(fakeBudgetRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
    addTearDown(fakeWorkspaceRepository.dispose);
    addTearDown(fakeBudgetRepository.dispose);
  });

  test('transactionsProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(transactionsProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([expense]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(transactionsProvider(workspaceId)).value, [expense]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(expense);

    final failure =
        await container.read(transactionFormControllerProvider.notifier).create(
              workspaceId: workspaceId,
              type: TransactionType.expense,
              description: 'Barbiere',
              amountCents: 2300,
              occurredAt: DateTime.utc(2026, 6, 15),
            );

    expect(failure, isNull);
    expect(fakeRepository.lastCreated, expense);
    expect(fakeRepository.lastCreatedCategory, TransactionCategory.altro);
  });

  test('create inoltra la categoria indicata al repository', () async {
    fakeRepository.createResult = Result.ok(expense);

    await container.read(transactionFormControllerProvider.notifier).create(
          workspaceId: workspaceId,
          type: TransactionType.expense,
          description: 'Barbiere',
          amountCents: 2300,
          occurredAt: DateTime.utc(2026, 6, 15),
          category: TransactionCategory.svago,
        );

    expect(fakeRepository.lastCreatedCategory, TransactionCategory.svago);
  });

  test('create con importo non valido ritorna un ValidationFailure', () async {
    fakeRepository.createResult = const Result.err(
        ValidationFailure('L\'importo deve essere maggiore di zero.'));

    final failure =
        await container.read(transactionFormControllerProvider.notifier).create(
              workspaceId: workspaceId,
              type: TransactionType.expense,
              description: 'Barbiere',
              amountCents: 0,
              occurredAt: DateTime.utc(2026, 6, 15),
            );

    expect(failure, isA<ValidationFailure>());
  });

  test('confirm e delete delegano al repository con l\'id giusto', () async {
    fakeRepository.confirmResult =
        Result.ok(expense.copyWith(status: TransactionStatus.confirmed));
    final controller =
        container.read(transactionFormControllerProvider.notifier);

    await controller.confirm(expense.id);
    expect(fakeRepository.lastConfirmedId, expense.id);

    await controller.delete(expense.id);
    expect(fakeRepository.lastDeletedId, expense.id);
  });

  test('updateTransaction delega al repository', () async {
    final controller =
        container.read(transactionFormControllerProvider.notifier);

    await controller.updateTransaction(expense);
    expect(fakeRepository.lastUpdated, expense);
  });

  test('attachDocument delega al repository con l\'id del documento', () async {
    fakeRepository.attachDocumentResult =
        Result.ok(expense.copyWith(description: expense.description));
    final controller =
        container.read(transactionFormControllerProvider.notifier);

    final failure = await controller.attachDocument(
        transactionId: expense.id, documentId: 'd1');

    expect(failure, isNull);
    expect(fakeRepository.lastAttachedTransactionId, expense.id);
    expect(fakeRepository.lastAttachedDocumentId, 'd1');
  });

  test('attachDocument con documentId null rimuove l\'allegato', () async {
    fakeRepository.attachDocumentResult = Result.ok(expense);
    final controller =
        container.read(transactionFormControllerProvider.notifier);

    await controller.attachDocument(
        transactionId: expense.id, documentId: null);

    expect(fakeRepository.attachDocumentCalled, isTrue);
    expect(fakeRepository.lastAttachedDocumentId, isNull);
  });

  group('confirmedThisMonth', () {
    test('include solo le transazioni confermate del mese di riferimento', () {
      final now = DateTime.utc(2026, 6, 20);
      final inMonth = expense.copyWith();
      final lastDayPreviousMonth =
          expense.copyWith(occurredAt: DateTime.utc(2026, 5, 31));
      final pendingInMonth = Transaction(
        id: 'e2',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Supermercato',
        amountCents: 3500,
        occurredAt: DateTime.utc(2026, 6, 10),
        status: TransactionStatus.pending,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = confirmedThisMonth(
        [inMonth, lastDayPreviousMonth, pendingInMonth],
        now: now,
      );

      expect(result, [inMonth]);
    });
  });

  group('pendingTransactions', () {
    test('include le transazioni pending indipendentemente dal mese', () {
      final pendingOtherMonth = Transaction(
        id: 'e3',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Spesa di maggio',
        amountCents: 1000,
        occurredAt: DateTime.utc(2026, 5, 1),
        status: TransactionStatus.pending,
        createdAt: DateTime.utc(2026, 5, 1),
      );

      final result = pendingTransactions([expense, pendingOtherMonth]);

      expect(result, [pendingOtherMonth]);
    });
  });

  group('totalIncomeCents / totalExpenseCents / balanceCents', () {
    final income = Transaction(
      id: 'i1',
      workspaceId: workspaceId,
      type: TransactionType.income,
      description: 'Stipendio',
      amountCents: 150000,
      occurredAt: DateTime.utc(2026, 6, 1),
      status: TransactionStatus.confirmed,
      createdAt: DateTime.utc(2026, 6, 1),
    );

    test('totalIncomeCents somma solo le entrate', () {
      expect(totalIncomeCents([income, expense]), 150000);
    });

    test('totalExpenseCents somma solo le uscite', () {
      expect(totalExpenseCents([income, expense]), 2300);
    });

    test('balanceCents è entrate meno uscite', () {
      expect(balanceCents([income, expense]), 150000 - 2300);
    });

    test('solo spese: il saldo è negativo', () {
      expect(balanceCents([expense]), -2300);
    });

    test('nessuna transazione: totali e saldo sono 0', () {
      expect(totalIncomeCents(const []), 0);
      expect(totalExpenseCents(const []), 0);
      expect(balanceCents(const []), 0);
    });
  });

  group('percentChange', () {
    test('calcola la percentuale di variazione', () {
      expect(percentChange(current: 120, previous: 100), 20);
      expect(percentChange(current: 80, previous: 100), -20);
    });

    test('previous 0 ritorna null (nessun confronto sensato)', () {
      expect(percentChange(current: 50, previous: 0), isNull);
    });

    test('previous negativo usa il valore assoluto come base', () {
      expect(percentChange(current: -50, previous: -100), 50);
    });
  });

  group('lastMonths', () {
    test('ritorna N mesi consecutivi fino al riferimento incluso, in ordine',
        () {
      // DateTime locale (non .utc): lastMonths preserva il tipo del
      // riferimento passato, coerente con DateTime.now() usato altrove in
      // questo file per il mese corrente.
      final months = lastMonths(DateTime(2026, 3, 1), 3);
      expect(months, [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      ]);
    });

    test('attraversa correttamente il cambio anno', () {
      final months = lastMonths(DateTime(2026, 1, 1), 3);
      expect(months, [
        DateTime(2025, 11, 1),
        DateTime(2025, 12, 1),
        DateTime(2026, 1, 1),
      ]);
    });
  });

  group('monthlyTotals', () {
    test('calcola entrate/uscite confermate per ciascun mese indicato', () {
      final juneIncome = Transaction(
        id: 'j1',
        workspaceId: workspaceId,
        type: TransactionType.income,
        description: 'Stipendio',
        amountCents: 150000,
        occurredAt: DateTime.utc(2026, 6, 1),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      final julyExpense = Transaction(
        id: 'j2',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Barbiere',
        amountCents: 2300,
        occurredAt: DateTime.utc(2026, 7, 5),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 7, 5),
      );
      final julyPending = Transaction(
        id: 'j3',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Suggerita, non confermata',
        amountCents: 9999,
        occurredAt: DateTime.utc(2026, 7, 10),
        status: TransactionStatus.pending,
        createdAt: DateTime.utc(2026, 7, 10),
      );

      final months = [DateTime.utc(2026, 6, 1), DateTime.utc(2026, 7, 1)];
      final totals =
          monthlyTotals([juneIncome, julyExpense, julyPending], months);

      expect(totals, hasLength(2));
      expect(totals[0].month, DateTime.utc(2026, 6, 1));
      expect(totals[0].incomeCents, 150000);
      expect(totals[0].expenseCents, 0);
      expect(totals[1].month, DateTime.utc(2026, 7, 1));
      expect(totals[1].incomeCents, 0);
      // La pending non conta: solo julyExpense (confirmed).
      expect(totals[1].expenseCents, 2300);
    });
  });

  group('categoryMonthlyTotals', () {
    test('calcola lo speso di una categoria per ciascun mese indicato', () {
      final juneBarbiere = Transaction(
        id: 'c1',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Barbiere',
        amountCents: 2300,
        occurredAt: DateTime.utc(2026, 6, 5),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 5),
        category: TransactionCategory.svago,
      );
      final juneSpesa = Transaction(
        id: 'c2',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Spesa',
        amountCents: 5000,
        occurredAt: DateTime.utc(2026, 6, 10),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 10),
        category: TransactionCategory.alimentari,
      );
      final julyBarbiere = Transaction(
        id: 'c3',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Barbiere',
        amountCents: 2500,
        occurredAt: DateTime.utc(2026, 7, 5),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 7, 5),
        category: TransactionCategory.svago,
      );

      final months = [DateTime.utc(2026, 6, 1), DateTime.utc(2026, 7, 1)];
      final totals = categoryMonthlyTotals(
        [juneBarbiere, juneSpesa, julyBarbiere],
        months,
        TransactionCategory.svago,
        type: TransactionType.expense,
      );

      expect(totals, [2300, 2500]);
    });

    test('non somma entrate e uscite della stessa categoria', () {
      final expense = Transaction(
        id: 'c4',
        workspaceId: workspaceId,
        type: TransactionType.expense,
        description: 'Uscita',
        amountCents: 1000,
        occurredAt: DateTime.utc(2026, 6, 5),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 5),
        category: TransactionCategory.altro,
      );
      final income = Transaction(
        id: 'c5',
        workspaceId: workspaceId,
        type: TransactionType.income,
        description: 'Entrata',
        amountCents: 9000,
        occurredAt: DateTime.utc(2026, 6, 6),
        status: TransactionStatus.confirmed,
        createdAt: DateTime.utc(2026, 6, 6),
        category: TransactionCategory.altro,
      );

      final totals = categoryMonthlyTotals(
        [expense, income],
        [DateTime.utc(2026, 6, 1)],
        TransactionCategory.altro,
        type: TransactionType.expense,
      );

      expect(totals, [1000]);
    });
  });

  group('projectedMonthEndExpenseCents', () {
    test('estrapola linearmente sui giorni del mese', () {
      // 15 giugno (30 giorni nel mese): metà mese esatta, 500€ spesi -> 1000€
      // proiettati a fine mese.
      final projected = projectedMonthEndExpenseCents(
        spentSoFarCents: 50000,
        now: DateTime.utc(2026, 6, 15),
      );

      expect(projected, 100000);
    });

    test('il primo giorno del mese non produce una proiezione', () {
      final projected = projectedMonthEndExpenseCents(
        spentSoFarCents: 2000,
        now: DateTime.utc(2026, 6, 1),
      );

      expect(projected, isNull);
    });

    test('attraversa correttamente mesi con un numero diverso di giorni', () {
      // Febbraio 2026 (non bisestile, 28 giorni): al giorno 14, metà mese.
      final projected = projectedMonthEndExpenseCents(
        spentSoFarCents: 14000,
        now: DateTime.utc(2026, 2, 14),
      );

      expect(projected, 28000);
    });

    test('a fine mese la proiezione coincide con lo speso reale', () {
      final projected = projectedMonthEndExpenseCents(
        spentSoFarCents: 30000,
        now: DateTime.utc(2026, 6, 30),
      );

      expect(projected, 30000);
    });
  });

  group('dailyExpenseTotals', () {
    Transaction buildTransaction({
      required String id,
      TransactionType type = TransactionType.expense,
      int amountCents = 2300,
      required DateTime occurredAt,
      TransactionStatus status = TransactionStatus.confirmed,
    }) {
      return Transaction(
        id: id,
        workspaceId: workspaceId,
        type: type,
        description: 'Test',
        amountCents: amountCents,
        occurredAt: occurredAt,
        status: status,
        createdAt: occurredAt,
      );
    }

    test('somma le uscite confermate per giorno del mese indicato', () {
      final expense1 = buildTransaction(
          id: 'e1', amountCents: 2300, occurredAt: DateTime.utc(2026, 6, 15));
      final expense2 = buildTransaction(
          id: 'e2', amountCents: 700, occurredAt: DateTime.utc(2026, 6, 15));
      final expenseOtherDay = buildTransaction(
          id: 'e3', amountCents: 1500, occurredAt: DateTime.utc(2026, 6, 3));

      final totals = dailyExpenseTotals(
        [expense1, expense2, expenseOtherDay],
        DateTime.utc(2026, 6, 1),
      );

      expect(totals, {15: 2300 + 700, 3: 1500});
    });

    test('esclude entrate, transazioni pending e mesi diversi', () {
      final confirmedExpense = buildTransaction(
          id: 'e1', amountCents: 2300, occurredAt: DateTime.utc(2026, 6, 15));
      final income = buildTransaction(
        id: 'i1',
        type: TransactionType.income,
        amountCents: 100000,
        occurredAt: DateTime.utc(2026, 6, 15),
      );
      final pending = buildTransaction(
        id: 'p1',
        occurredAt: DateTime.utc(2026, 6, 15),
        status: TransactionStatus.pending,
      );
      final otherMonth =
          buildTransaction(id: 'o1', occurredAt: DateTime.utc(2026, 5, 15));

      final totals = dailyExpenseTotals(
        [confirmedExpense, income, pending, otherMonth],
        DateTime.utc(2026, 6, 1),
      );

      expect(totals, {15: 2300});
    });

    test('nessuna uscita confermata produce una mappa vuota', () {
      final totals = dailyExpenseTotals([], DateTime.utc(2026, 6, 1));

      expect(totals, isEmpty);
    });
  });

  group('notifica push su budget quasi superato', () {
    // Riferite a "adesso" (non a una data fissa come `expense` sopra):
    // `_maybeAlertBudget` valuta sempre il mese corrente reale, come la
    // Edge Function `send-budget-alert` lato server.
    final now = DateTime.now();
    final budget = CategoryBudget(
      id: 'b1',
      category: TransactionCategory.svago,
      monthlyLimitCents: 10000,
      updatedAt: now,
    );
    final existingSpend = Transaction(
      id: 'existing',
      workspaceId: workspaceId,
      type: TransactionType.expense,
      description: 'Cinema',
      amountCents: 3000,
      category: TransactionCategory.svago,
      occurredAt: now,
      status: TransactionStatus.confirmed,
      createdAt: now,
    );

    // `transactionsProvider(null)`/`workspacesProvider`/`budgetsProvider`
    // sono `.autoDispose`: senza un ascoltatore attivo prima dell'emit, un
    // `ref.read` successivo troverebbe uno stream broadcast già "passato"
    // (nessun replay ai nuovi iscritti) — stesso bug di ordinamento già
    // risolto per `currentMemberRoleProvider` (Slice 3). Il test sottoscrive
    // prima di emettere, come già fa il primo test di questo file.
    Future<void> warmUpAndEmit({
      required List<Workspace> workspaces,
      required List<CategoryBudget> budgets,
      required List<Transaction> transactions,
    }) async {
      container.listen(workspacesProvider, (_, __) {});
      container.listen(budgetsProvider, (_, __) {});
      container.listen(transactionsProvider(null), (_, __) {});
      fakeWorkspaceRepository.emit(workspaces);
      fakeBudgetRepository.emit(budgets);
      fakeRepository.emit(transactions);
      await Future<void>.delayed(Duration.zero);
    }

    test(
        'create di una spesa che supera la soglia chiama checkBudgetAlert con lo speso aggiornato',
        () async {
      await warmUpAndEmit(
        workspaces: [workspace],
        budgets: [budget],
        transactions: [existingSpend],
      );
      fakeRepository.createResult =
          Result.ok(existingSpend.copyWith(amountCents: 9000));

      await container.read(transactionFormControllerProvider.notifier).create(
            workspaceId: workspaceId,
            type: TransactionType.expense,
            description: 'Concerto',
            amountCents: 9000,
            occurredAt: now,
            category: TransactionCategory.svago,
          );

      expect(fakeBudgetRepository.alertCallCount, 1);
      expect(fakeBudgetRepository.lastAlertBudgetId, 'b1');
      expect(fakeBudgetRepository.lastAlertCategory, TransactionCategory.svago);
      // 3000 (già confermato questo mese) + 9000 (appena creata) = 12000.
      expect(fakeBudgetRepository.lastAlertSpentCents, 12000);
      expect(fakeBudgetRepository.lastAlertLimitCents, 10000);
    });

    test('create senza budget per la categoria non chiama checkBudgetAlert',
        () async {
      await warmUpAndEmit(
        workspaces: [workspace],
        budgets: const [],
        transactions: const [],
      );
      fakeRepository.createResult = Result.ok(existingSpend);

      await container.read(transactionFormControllerProvider.notifier).create(
            workspaceId: workspaceId,
            type: TransactionType.expense,
            description: 'Concerto',
            amountCents: 9000,
            occurredAt: now,
            category: TransactionCategory.svago,
          );

      expect(fakeBudgetRepository.alertCallCount, 0);
    });

    test('create di un\'entrata non chiama mai checkBudgetAlert', () async {
      await warmUpAndEmit(
        workspaces: [workspace],
        budgets: [budget],
        transactions: [existingSpend],
      );
      final income = existingSpend.copyWith();
      fakeRepository.createResult = Result.ok(income);

      await container.read(transactionFormControllerProvider.notifier).create(
            workspaceId: workspaceId,
            type: TransactionType.income,
            description: 'Stipendio',
            amountCents: 9000,
            occurredAt: now,
            category: TransactionCategory.svago,
          );

      expect(fakeBudgetRepository.alertCallCount, 0);
    });

    test(
        'create in un Bilancio condiviso non chiama checkBudgetAlert (i budget sono solo personali)',
        () async {
      final sharedWorkspace =
          workspace.copyWith(category: sharedBalanceCategory);
      await warmUpAndEmit(
        workspaces: [sharedWorkspace],
        budgets: [budget],
        transactions: [existingSpend],
      );
      fakeRepository.createResult =
          Result.ok(existingSpend.copyWith(amountCents: 9000));

      await container.read(transactionFormControllerProvider.notifier).create(
            workspaceId: workspaceId,
            type: TransactionType.expense,
            description: 'Concerto',
            amountCents: 9000,
            occurredAt: now,
            category: TransactionCategory.svago,
          );

      expect(fakeBudgetRepository.alertCallCount, 0);
    });

    test('confirm di una spesa che supera la soglia chiama checkBudgetAlert',
        () async {
      await warmUpAndEmit(
        workspaces: [workspace],
        budgets: [budget],
        transactions: [existingSpend],
      );
      final confirmedTransaction = existingSpend.copyWith(amountCents: 8000);
      fakeRepository.confirmResult = Result.ok(confirmedTransaction);

      await container
          .read(transactionFormControllerProvider.notifier)
          .confirm('pending1');

      expect(fakeBudgetRepository.alertCallCount, 1);
      // 3000 (già confermato) + 8000 (appena confermata) = 11000.
      expect(fakeBudgetRepository.lastAlertSpentCents, 11000);
    });
  });
}
