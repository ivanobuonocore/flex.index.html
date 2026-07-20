import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/workspace/application/workspace_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_workspace_repository.dart';

void main() {
  final workspace = Workspace(
    id: 'w1',
    ownerId: 'u1',
    name: 'Lavoro',
    icon: 'briefcase',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  late FakeWorkspaceRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeWorkspaceRepository();
    container = ProviderContainer(
      overrides: [
        workspaceRepositoryProvider.overrideWithValue(fakeRepository)
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('workspacesProvider riflette lo stream del repository', () async {
    final subscription = container.listen(workspacesProvider, (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emit([workspace]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(workspacesProvider).value, [workspace]);
  });

  test('create con successo non ritorna errore', () async {
    fakeRepository.createResult = Result.ok(workspace);

    final failure = await container
        .read(workspaceFormControllerProvider.notifier)
        .create(name: 'Lavoro', icon: 'briefcase');

    expect(failure, isNull);
    expect(fakeRepository.lastCreated, workspace);
  });

  test('create con nome vuoto ritorna un ValidationFailure', () async {
    fakeRepository.createResult =
        const Result.err(ValidationFailure('Il nome è obbligatorio.'));

    final failure = await container
        .read(workspaceFormControllerProvider.notifier)
        .create(name: '', icon: 'briefcase');

    expect(failure, isA<ValidationFailure>());
  });

  test('updateWorkspace e delete delegano al repository', () async {
    fakeRepository.updateResult = Result.ok(workspace);

    final updateFailure = await container
        .read(workspaceFormControllerProvider.notifier)
        .updateWorkspace(workspace);
    expect(updateFailure, isNull);
    expect(fakeRepository.lastUpdated, workspace);

    final deleteFailure = await container
        .read(workspaceFormControllerProvider.notifier)
        .delete(workspace.id);
    expect(deleteFailure, isNull);
    expect(fakeRepository.lastArchivedId, workspace.id);
  });

  test(
      'workspacesProvider filtra le sezioni fisse duplicate, mantenendo la più vecchia',
      () async {
    final oldAppuntamenti = Workspace(
      id: 'w-appuntamenti-old',
      ownerId: 'u1',
      name: 'Appuntamenti',
      icon: 'folder',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 1, 1),
      category: SystemWorkspaceCategory.appuntamenti,
    );
    final newAppuntamenti = Workspace(
      id: 'w-appuntamenti-new',
      ownerId: 'u1',
      name: 'Appuntamenti',
      icon: 'folder',
      status: WorkspaceStatus.active,
      createdAt: DateTime.utc(2026, 2, 1),
      category: SystemWorkspaceCategory.appuntamenti,
    );

    final subscription = container.listen(workspacesProvider, (_, __) {});
    addTearDown(subscription.close);
    // Workspace libero senza categoria (mai deduplicato) + 2 duplicati della
    // stessa sezione fissa, in ordine "più recente prima" (come restituito
    // dal repository reale, created_at desc).
    fakeRepository.emit([newAppuntamenti, workspace, oldAppuntamenti]);
    await Future<void>.delayed(Duration.zero);

    final result = container.read(workspacesProvider).value!;

    expect(
      result
          .where((w) => w.category == SystemWorkspaceCategory.appuntamenti)
          .length,
      1,
    );
    expect(
      result
          .firstWhere((w) => w.category == SystemWorkspaceCategory.appuntamenti)
          .id,
      oldAppuntamenti.id,
    );
    expect(result.any((w) => w.id == workspace.id), isTrue);
  });

  test('workspaceBootstrapProvider crea solo le sezioni fisse mancanti',
      () async {
    final bilancio =
        workspace.copyWith(category: SystemWorkspaceCategory.bilancio);
    fakeRepository.createResult = Result.ok(bilancio);

    final subscription = container.listen(workspacesProvider, (_, __) {});
    addTearDown(subscription.close);
    fakeRepository.emit([
      workspace, // Workspace libero, nessuna categoria: non conta come sezione fissa
      workspace.copyWith(category: SystemWorkspaceCategory.bilancio),
    ]);
    await Future<void>.delayed(Duration.zero);

    await container.read(workspaceBootstrapProvider.future);

    expect(
      fakeRepository.createdCategories,
      unorderedEquals([
        SystemWorkspaceCategory.appuntamenti,
        SystemWorkspaceCategory.attivita,
        SystemWorkspaceCategory.documenti,
      ]),
    );
  });

  test('workspaceBootstrapProvider non crea nulla se le 4 sezioni esistono già',
      () async {
    final subscription = container.listen(workspacesProvider, (_, __) {});
    addTearDown(subscription.close);
    fakeRepository.emit([
      for (final category in SystemWorkspaceCategory.all)
        workspace.copyWith(category: category),
    ]);
    await Future<void>.delayed(Duration.zero);

    await container.read(workspaceBootstrapProvider.future);

    expect(fakeRepository.createdCategories, isEmpty);
  });
}
