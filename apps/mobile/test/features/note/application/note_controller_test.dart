import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/note/application/note_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_note_repository.dart';

void main() {
  const workspaceId = 'w1';
  final note = Note(
    id: 'n1',
    workspaceId: workspaceId,
    title: 'Idea',
    content: 'contenuto',
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  late FakeNoteRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeNoteRepository();
    container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(fakeRepository)],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('notesProvider riflette lo stream del repository per workspace',
      () async {
    final subscription =
        container.listen(notesProvider(workspaceId), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([note]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(notesProvider(workspaceId)).value, [note]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(note);

    final failure = await container
        .read(noteFormControllerProvider.notifier)
        .create(workspaceId: workspaceId, title: 'Idea');

    expect(failure, isNull);
    expect(fakeRepository.lastCreated, note);
  });

  test('create inoltra i tag al repository', () async {
    fakeRepository.createResult = Result.ok(note);

    await container.read(noteFormControllerProvider.notifier).create(
      workspaceId: workspaceId,
      title: 'Idea',
      tags: const ['lavoro', 'urgente'],
    );

    expect(fakeRepository.lastCreatedTags, ['lavoro', 'urgente']);
  });

  test('create con titolo vuoto ritorna un ValidationFailure', () async {
    fakeRepository.createResult =
        const Result.err(ValidationFailure('Il titolo è obbligatorio.'));

    final failure = await container
        .read(noteFormControllerProvider.notifier)
        .create(workspaceId: workspaceId, title: '');

    expect(failure, isA<ValidationFailure>());
  });

  test('updateNote e delete delegano al repository', () async {
    final controller = container.read(noteFormControllerProvider.notifier);

    await controller.updateNote(note);
    expect(fakeRepository.lastUpdated, note);

    await controller.delete(note.id);
    expect(fakeRepository.lastDeletedId, note.id);
  });
}
