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
}
