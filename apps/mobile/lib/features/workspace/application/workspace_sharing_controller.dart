import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';

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

  Future<Result<WorkspaceInvite>> createInvite(
    String workspaceId, {
    WorkspaceRole role = WorkspaceRole.editor,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(workspaceSharingRepositoryProvider)
        .createInvite(workspaceId, role: role);
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

  Future<Failure?> updateMemberRole({
    required String workspaceId,
    required String userId,
    required WorkspaceRole role,
  }) async {
    state = const AsyncLoading();
    final result =
        await ref.read(workspaceSharingRepositoryProvider).updateMemberRole(
              workspaceId: workspaceId,
              userId: userId,
              role: role,
            );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}

/// Ruolo dell'utente autenticato in [workspaceId] — `null` se è il
/// proprietario o se non è un Workspace condiviso (accesso pieno in
/// entrambi i casi, il chiamante non deve distinguerli). Riusa
/// [workspaceMembersProvider]: sotto RLS, un membro vede sempre e solo la
/// propria riga in `workspace_members` (mai quelle altrui), quindi non serve
/// una query/un metodo di repository dedicato.
final currentMemberRoleProvider =
    Provider.autoDispose.family<WorkspaceRole?, String>((ref, workspaceId) {
  // Entrambi i watch incondizionati (non un early-return su `userId == null`):
  // sottoscrivono `workspaceMembersProvider` fin dalla prima valutazione,
  // indipendentemente da quando la sessione si risolve — altrimenti la
  // sottoscrizione partirebbe in ritardo, dopo che l'evento è già stato
  // emesso (osservato nei test, dove uno StreamController broadcast non
  // riproduce gli eventi persi a un iscritto tardivo).
  final userId = ref.watch(sessionControllerProvider).asData?.value?.id;
  final members =
      ref.watch(workspaceMembersProvider(workspaceId)).asData?.value ??
          const [];
  if (userId == null) return null;
  for (final member in members) {
    if (member.userId == userId) return member.role;
  }
  return null;
});
