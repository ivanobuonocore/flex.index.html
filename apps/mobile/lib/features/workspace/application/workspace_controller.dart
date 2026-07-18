import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Workspace dell'utente autenticato, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final workspacesProvider = StreamProvider.autoDispose<List<Workspace>>((ref) {
  return ref.watch(workspaceRepositoryProvider).watchWorkspaces();
});

final workspaceFormControllerProvider =
    AsyncNotifierProvider.autoDispose<WorkspaceFormController, void>(
  WorkspaceFormController.new,
);

class WorkspaceFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> create({
    required String name,
    required String icon,
    String? description,
    String? category,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(workspaceRepositoryProvider).createWorkspace(
          name: name,
          icon: icon,
          description: description,
          category: category,
        );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
