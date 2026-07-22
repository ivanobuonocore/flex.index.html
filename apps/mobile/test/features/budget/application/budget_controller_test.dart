import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/budget/application/budget_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_budget_repository.dart';

void main() {
  final budget = CategoryBudget(
    id: 'b1',
    category: TransactionCategory.alimentari,
    monthlyLimitCents: 30000,
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  late FakeBudgetRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeBudgetRepository();
    container = ProviderContainer(
      overrides: [
        budgetRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('budgetsProvider riflette lo stream del repository', () async {
    final subscription = container.listen(budgetsProvider, (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([budget]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(budgetsProvider).value, [budget]);
  });

  test('setBudget con successo non ritorna errore', () async {
    fakeRepository.setResult = Result.ok(budget);

    final failure = await container
        .read(budgetFormControllerProvider.notifier)
        .setBudget(
            category: TransactionCategory.alimentari, monthlyLimitCents: 30000);

    expect(failure, isNull);
    expect(fakeRepository.lastSetCategory, TransactionCategory.alimentari);
    expect(fakeRepository.lastSetMonthlyLimitCents, 30000);
  });

  test('setBudget con importo non valido ritorna un ValidationFailure',
      () async {
    fakeRepository.setResult = const Result.err(
        ValidationFailure('Il budget deve essere maggiore di zero.'));

    final failure = await container
        .read(budgetFormControllerProvider.notifier)
        .setBudget(
            category: TransactionCategory.alimentari, monthlyLimitCents: 0);

    expect(failure, isA<ValidationFailure>());
  });

  test('deleteBudget delega al repository', () async {
    final failure = await container
        .read(budgetFormControllerProvider.notifier)
        .deleteBudget('b1');

    expect(failure, isNull);
    expect(fakeRepository.lastDeletedId, 'b1');
  });
}
