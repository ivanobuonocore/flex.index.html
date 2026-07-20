import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_mobile/core/providers.dart';
import 'package:pip_mobile/features/workspace/application/workspace_sharing_controller.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../support/fake_workspace_sharing_repository.dart';

void main() {
  final workspace = Workspace(
    id: 'w1',
    ownerId: 'u1',
    name: 'Bilancio condiviso',
    icon: 'group',
    status: WorkspaceStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
    category: sharedBalanceCategory,
  );
  final invite = WorkspaceInvite(
    id: 'i1',
    workspaceId: 'w1',
    code: 'ABCD1234',
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 1, 1),
    expiresAt: DateTime.utc(2026, 1, 8),
  );
  final member = WorkspaceMember(
    id: 'm1',
    workspaceId: 'w1',
    userId: 'u2',
    joinedAt: DateTime.utc(2026, 1, 2),
  );

  late FakeWorkspaceSharingRepository fakeRepository;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = FakeWorkspaceSharingRepository();
    container = ProviderContainer(
      overrides: [
        workspaceSharingRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fakeRepository.dispose);
  });

  test('sharedBalancesProvider riflette lo stream del repository', () async {
    final subscription = container.listen(sharedBalancesProvider, (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emitSharedBalances([workspace]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(sharedBalancesProvider).value, [workspace]);
  });

  test(
      'workspaceMembersProvider riflette lo stream del repository per Workspace',
      () async {
    final subscription =
        container.listen(workspaceMembersProvider('w1'), (_, __) {});
    addTearDown(subscription.close);

    fakeRepository.emitMembers('w1', [member]);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(workspaceMembersProvider('w1')).value, [member]);
  });

  test('createInvite delega al repository e ritorna l\'invito', () async {
    fakeRepository.createInviteResult = Result.ok(invite);

    final result = await container
        .read(workspaceSharingFormControllerProvider.notifier)
        .createInvite('w1');

    expect(result.isOk, isTrue);
    expect((result as Ok<WorkspaceInvite>).value, invite);
    expect(fakeRepository.lastInvitedWorkspaceId, 'w1');
  });

  test('redeemInvite delega al repository e ritorna il Workspace', () async {
    fakeRepository.redeemInviteResult = Result.ok(workspace);

    final result = await container
        .read(workspaceSharingFormControllerProvider.notifier)
        .redeemInvite('ABCD1234');

    expect(result.isOk, isTrue);
    expect((result as Ok<Workspace>).value, workspace);
    expect(fakeRepository.lastRedeemedCode, 'ABCD1234');
  });

  test('redeemInvite con codice non valido ritorna un ValidationFailure',
      () async {
    fakeRepository.redeemInviteResult =
        const Result.err(ValidationFailure('Codice d\'invito non valido.'));

    final result = await container
        .read(workspaceSharingFormControllerProvider.notifier)
        .redeemInvite('XXXXXXXX');

    expect(result.isErr, isTrue);
    expect((result as Err<Workspace>).failure, isA<ValidationFailure>());
  });

  test('removeMember delega al repository con workspaceId e userId', () async {
    final failure = await container
        .read(workspaceSharingFormControllerProvider.notifier)
        .removeMember(workspaceId: 'w1', userId: 'u2');

    expect(failure, isNull);
    expect(fakeRepository.lastRemovedMember, (workspaceId: 'w1', userId: 'u2'));
  });
}
