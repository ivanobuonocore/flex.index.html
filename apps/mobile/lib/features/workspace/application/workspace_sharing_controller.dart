import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Bilanci condivisi dell'utente autenticato — posseduti o di cui è membro
/// (Fase 3, "Bilancio condiviso").
final sharedBalancesProvider =
    StreamProvider.autoDispose<List<Workspace>>((ref) {
  return ref.watch(workspaceSharingRepositoryProvider).watchSharedBalances();
});

/// Membri (diversi dal proprietario) di un Bilancio condiviso, in tempo reale.
final workspaceMembersProvider =
    StreamProvider.autoDispose.family<List<WorkspaceMember>, String>(
  (ref, workspaceId) =>
      ref.watch(workspaceSharingRepositoryProvider).watchMembers(workspaceId),
);

final workspaceSharingFormControllerProvider =
    AsyncNotifierProvider.autoDispose<WorkspaceSharingFormController, void>(
        WorkspaceSharingFormController.new);

class WorkspaceSharingFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Result<WorkspaceInvite>> createInvite(String workspaceId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(workspaceSharingRepositoryProvider)
        .createInvite(workspaceId);
    state = const AsyncData(null);
    return result;
  }

  Future<Result<Workspace>> redeemInvite(String code) async {
    state = const AsyncLoading();
    final result =
        await ref.read(workspaceSharingRepositoryProvider).redeemInvite(code);
    state = const AsyncData(null);
    return result;
  }

  Future<Failure?> removeMember({
    required String workspaceId,
    required String userId,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(workspaceSharingRepositoryProvider)
        .removeMember(workspaceId: workspaceId, userId: userId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
