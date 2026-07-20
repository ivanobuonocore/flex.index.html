import 'dart:async';

import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

class FakeWorkspaceSharingRepository implements WorkspaceSharingRepository {
  FakeWorkspaceSharingRepository({
    this.createInviteResult,
    this.redeemInviteResult,
    this.removeMemberResult,
  });

  final _sharedBalancesController =
      StreamController<List<Workspace>>.broadcast();
  final _membersControllers =
      <String, StreamController<List<WorkspaceMember>>>{};

  Result<WorkspaceInvite>? createInviteResult;
  Result<Workspace>? redeemInviteResult;
  Result<Unit>? removeMemberResult;

  String? lastInvitedWorkspaceId;
  String? lastRedeemedCode;
  ({String workspaceId, String userId})? lastRemovedMember;

  void emitSharedBalances(List<Workspace> workspaces) =>
      _sharedBalancesController.add(workspaces);

  void emitMembers(String workspaceId, List<WorkspaceMember> members) {
    _membersControllerFor(workspaceId).add(members);
  }

  StreamController<List<WorkspaceMember>> _membersControllerFor(
      String workspaceId) {
    return _membersControllers.putIfAbsent(
        workspaceId, () => StreamController<List<WorkspaceMember>>.broadcast());
  }

  @override
  Stream<List<Workspace>> watchSharedBalances() =>
      _sharedBalancesController.stream;

  @override
  Stream<List<WorkspaceMember>> watchMembers(String workspaceId) =>
      _membersControllerFor(workspaceId).stream;

  @override
  Future<Result<WorkspaceInvite>> createInvite(String workspaceId) async {
    lastInvitedWorkspaceId = workspaceId;
    return createInviteResult ??
        const Result<WorkspaceInvite>.err(
            ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Workspace>> redeemInvite(String code) async {
    lastRedeemedCode = code;
    return redeemInviteResult ??
        const Result<Workspace>.err(
            ValidationFailure('Nessun risultato configurato.'));
  }

  @override
  Future<Result<Unit>> removeMember({
    required String workspaceId,
    required String userId,
  }) async {
    lastRemovedMember = (workspaceId: workspaceId, userId: userId);
    return removeMemberResult ?? const Result.ok(unit);
  }

  void dispose() {
    _sharedBalancesController.close();
    for (final controller in _membersControllers.values) {
      controller.close();
    }
  }
}
