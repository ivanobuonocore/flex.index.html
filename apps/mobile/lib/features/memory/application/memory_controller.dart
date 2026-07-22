import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Memorie globali dell'utente corrente, in tempo reale (Software
/// Architecture, "Sincronizzazione" — Realtime lato Supabase).
final globalMemoriesProvider = StreamProvider.autoDispose<List<Memory>>(
  (ref) => ref.watch(memoryRepositoryProvider).watchGlobalMemories(),
);

/// Memorie di un Workspace specifico (richiesta esplicita dell'utente:
/// "Memoria a livello Workspace"), in tempo reale.
final workspaceMemoriesProvider =
    StreamProvider.autoDispose.family<List<Memory>, String>(
  (ref, workspaceId) =>
      ref.watch(memoryRepositoryProvider).watchWorkspaceMemories(workspaceId),
);

final memoryFormControllerProvider =
    AsyncNotifierProvider.autoDispose<MemoryFormController, void>(
        MemoryFormController.new);

/// Il Globale è scritto solo dall'AI (tool `remember_fact`) — nessun metodo
/// di creazione qui. Il Workspace è creato manualmente dall'utente (vedi
/// [MemoryRepository]).
class MemoryFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> createForWorkspace({
    required String workspaceId,
    required String content,
  }) async {
    state = const AsyncLoading();
    final result =
        await ref.read(memoryRepositoryProvider).createWorkspaceMemory(
              workspaceId: workspaceId,
              content: content,
            );
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  Future<Failure?> delete(String memoryId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(memoryRepositoryProvider).deleteMemory(memoryId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
