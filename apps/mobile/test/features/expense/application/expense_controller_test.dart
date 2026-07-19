import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/expense/application/expense_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_expense_repository.dart';

void main() {
  const workspaceId = 'w1';
  final expense = Expense(
    id: 'e1',
    workspaceId: workspaceId,
    description: 'Barbiere',
    amountCents: 2300,
    occurredAt: DateTime.utc(2026, 6, 15),
    status: ExpenseStatus.confirmed,
    createdAt: DateTime.utc(2026, 6, 15),
  );

  late FakeExpenseRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeExpenseRepository();
    container = ProviderContainer(
      overrides: [expenseRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('expensesProvider riflette lo stream del repository per workspace', () async {
    final subscription = container.listen(expensesProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([expense]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(expensesProvider(workspaceId)).value, [expense]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(expense);

    final failure = await container.read(expenseFormControllerProvider.notifier).create(
          workspaceId: workspaceId,
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

    final failure = await container.read(expenseFormControllerProvider.notifier).create(
          workspaceId: workspaceId,
          description: 'Barbiere',
          amountCents: 0,
          occurredAt: DateTime.utc(2026, 6, 15),
        );

    expect(failure, isA<ValidationFailure>());
  });

  test('confirm e delete delegano al repository con l\'id giusto', () async {
    fakeRepository.confirmResult = Result.ok(expense.copyWith(status: ExpenseStatus.confirmed));
    final controller = container.read(expenseFormControllerProvider.notifier);

    await controller.confirm(expense.id);
    expect(fakeRepository.lastConfirmedId, expense.id);

    await controller.delete(expense.id);
    expect(fakeRepository.lastDeletedId, expense.id);
  });

  test('updateExpense delega al repository', () async {
    final controller = container.read(expenseFormControllerProvider.notifier);

    await controller.updateExpense(expense);
    expect(fakeRepository.lastUpdated, expense);
  });

  group('confirmedThisMonth', () {
    test('include solo le spese confermate del mese di riferimento', () {
      final now = DateTime.utc(2026, 6, 20);
      final inMonth = expense.copyWith();
      final lastDayPreviousMonth = expense.copyWith(occurredAt: DateTime.utc(2026, 5, 31));
      final pendingInMonth = Expense(
        id: 'e2',
        workspaceId: workspaceId,
        description: 'Supermercato',
        amountCents: 3500,
        occurredAt: DateTime.utc(2026, 6, 10),
        status: ExpenseStatus.pending,
        createdAt: DateTime.utc(2026, 6, 10),
      );

      final result = confirmedThisMonth(
        [inMonth, lastDayPreviousMonth, pendingInMonth],
        now: now,
      );

      expect(result, [inMonth]);
    });
  });

  group('pendingExpenses', () {
    test('include le spese pending indipendentemente dal mese', () {
      final pendingOtherMonth = Expense(
        id: 'e3',
        workspaceId: workspaceId,
        description: 'Spesa di maggio',
        amountCents: 1000,
        occurredAt: DateTime.utc(2026, 5, 1),
        status: ExpenseStatus.pending,
        createdAt: DateTime.utc(2026, 5, 1),
      );

      final result = pendingExpenses([expense, pendingOtherMonth]);

      expect(result, [pendingOtherMonth]);
    });
  });

  group('totalCents', () {
    test('somma gli importi delle spese indicate', () {
      final other = expense.copyWith(amountCents: 100);
      expect(totalCents([expense, other]), 2400);
    });

    test('ritorna 0 per una lista vuota', () {
      expect(totalCents(const []), 0);
    });
  });
}
