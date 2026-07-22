import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/recurring_transaction/application/recurring_transaction_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_recurring_transaction_repository.dart';

void main() {
  final template = RecurringTransactionTemplate(
    id: 'r1',
    workspaceId: 'w1',
    type: TransactionType.expense,
    description: 'Netflix',
    amountCents: 1599,
    category: TransactionCategory.svago,
    frequency: RecurrenceFrequency.monthly,
    nextOccurrenceAt: DateTime.utc(2026, 8, 1),
    anchorDay: 1,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeRecurringTransactionRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeRecurringTransactionRepository();
    container = ProviderContainer(
      overrides: [
        recurringTransactionRepositoryProvider
            .overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test(
      'recurringTransactionsProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(recurringTransactionsProvider('w1'), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([template]);
    await Future<void>.delayed(Duration.zero);

    expect(
        container.read(recurringTransactionsProvider('w1')).value, [template]);
  });

  test('delete delega al repository', () async {
    final failure = await container
        .read(recurringTransactionFormControllerProvider.notifier)
        .delete('r1');

    expect(failure, isNull);
    expect(fakeRepository.lastDeletedId, 'r1');
  });

  test('delete con errore ritorna il Failure del repository', () async {
    fakeRepository.deleteResult = const Result.err(UnexpectedFailure(
        'Non è stato possibile eliminare la spesa ricorrente.'));

    final failure = await container
        .read(recurringTransactionFormControllerProvider.notifier)
        .delete('r1');

    expect(failure, isA<UnexpectedFailure>());
  });
}
