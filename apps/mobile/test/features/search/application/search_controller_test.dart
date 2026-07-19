import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/search/application/search_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_search_repository.dart';

void main() {
  const result = SearchResult(
    type: SearchResultType.note,
    id: 'n1',
    workspaceId: 'w1',
    title: 'Idea',
  );

  late FakeSearchRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeSearchRepository();
    container = ProviderContainer(
      overrides: [searchRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
  });

  test('lo stato iniziale è una lista vuota, senza chiamare il repository',
      () async {
    // build() è async: attendo la risoluzione prima di leggere .value, altrimenti
    // lo stato è ancora AsyncLoading (value == null) subito dopo la creazione.
    final initial = await container.read(searchControllerProvider.future);

    expect(initial, isEmpty);
    expect(fakeRepository.lastQuery, isNull);
  });

  test(
      'search con query vuota svuota i risultati senza interrogare il repository',
      () async {
    await container.read(searchControllerProvider.notifier).search('   ');

    expect(container.read(searchControllerProvider).value, isEmpty);
    expect(fakeRepository.lastQuery, isNull);
  });

  test('search con successo popola i risultati', () async {
    fakeRepository.result = const Result.ok([result]);

    await container.read(searchControllerProvider.notifier).search('idea');

    expect(container.read(searchControllerProvider).value, [result]);
    expect(fakeRepository.lastQuery, 'idea');
  });

  test('search con errore imposta uno stato di errore', () async {
    fakeRepository.result = const Result.err(
        UnexpectedFailure('Non è stato possibile completare la ricerca.'));

    await container.read(searchControllerProvider.notifier).search('idea');

    final state = container.read(searchControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<UnexpectedFailure>());
  });
}
