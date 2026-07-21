import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/memory/application/memory_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_memory_repository.dart';

void main() {
  final memory = Memory(
    id: 'm1',
    content: 'Preferisce il caffè la mattina',
    level: MemoryLevel.global,
    origin: MemoryOrigin.ai,
    userId: 'u1',
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  late FakeMemoryRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeMemoryRepository();
    container = ProviderContainer(
      overrides: [
        memoryRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('globalMemoriesProvider riflette lo stream del repository', () async {
    final subscription = container.listen(globalMemoriesProvider, (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([memory]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(globalMemoriesProvider).value, [memory]);
  });

  test('delete delega al repository', () async {
    final failure = await container
        .read(memoryFormControllerProvider.notifier)
        .delete('m1');

    expect(failure, isNull);
    expect(fakeRepository.lastDeletedId, 'm1');
  });

  test('delete con errore ritorna il Failure del repository', () async {
    fakeRepository.deleteResult = const Result.err(
        UnexpectedFailure('Non è stato possibile eliminare la memoria.'));

    final failure = await container
        .read(memoryFormControllerProvider.notifier)
        .delete('m1');

    expect(failure, isA<UnexpectedFailure>());
  });
}
