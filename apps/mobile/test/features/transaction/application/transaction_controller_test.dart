import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/transaction/application/transaction_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_transaction_repository.dart';

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

  late FakeTransactionRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeTransactionRepository();
    container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('transactionsProvider riflette lo stream del repository per workspace', () async {
    final subscription = container.listen(transactionsProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([expense]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(transactionsProvider(workspaceId)).value, [expense]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(expense);

    final failure = await container.read(transactionFormControllerProvider.notifier).create(
          workspaceId: workspaceId,
          type: TransactionType.expense,
          description: 'Barbiere',
          amountCents: 2300,
          occurredAt: DateTime.utc(2026, 6, 15),
        );

    expect(failure, isNull);
    expect(fakeRepository.lastCreated, expense);
  });

  test('create con importo non valido ritorna un ValidationFailure', () async {
    fakeRepository.createResult =
        const Result.err(ValidationFailure('L\'importo deve essere maggiore di zero.'));

    final failure = await container.read(transactionFormControllerProvider.notifier).create(
          workspaceId: workspaceId,
          type: TransactionType.expense,
          description: 'Barbiere',
          amountCents: 0,
          occurredAt: DateTime.utc(2026, 6, 15),
        );

    expect(failure, isA<ValidationFailure>());
  });

  test('confirm e delete delegano al repository con l\'id giusto', () async {
    fakeRepository.confirmResult = Result.ok(expense.copyWith(status: TransactionStatus.confirmed));
    final controller = container.read(transactionFormControllerProvider.notifier);

    await controller.confirm(expense.id);
    expect(fakeRepository.lastConfirmedId, expense.id);

    await controller.delete(expense.id);
    expect(fakeRepository.lastDeletedId, expense.id);
  });

  test('updateTransaction delega al repository', () async {
    final controller = container.read(transactionFormControllerProvider.notifier);

    await controller.updateTransaction(expense);
    expect(fakeRepository.lastUpdated, expense);
  });

  group('confirmedThisMonth', () {
    test('include solo le transazioni confermate del mese di riferimento', () {
      final now = DateTime.utc(2026, 6, 20);
      final inMonth = expense.copyWith();
      final lastDayPreviousMonth = expense.copyWith(occurredAt: DateTime.utc(2026, 5, 31));
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
}
