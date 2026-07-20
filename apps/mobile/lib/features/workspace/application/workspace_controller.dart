import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import 'workspace_category_meta.dart';

/// Workspace dell'utente autenticato, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase).
final workspacesProvider = StreamProvider.autoDispose<List<Workspace>>((ref) {
  return ref.watch(workspaceRepositoryProvider).watchWorkspaces();
});

/// Garantisce che le 4 sezioni fisse (Fase 3, "Sezioni fisse" — richiesta
/// esplicita dell'utente) esistano per l'utente autenticato, creando solo
/// quelle che mancano. Idempotente: letto ogni volta che si apre la Home
/// Chat, non ricrea sezioni già presenti. Non usa una migrazione/trigger
/// perché deve valere anche per gli utenti già esistenti (non solo per le
/// nuove registrazioni).
final workspaceBootstrapProvider =
    FutureProvider.autoDispose<void>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  final existingCategories =
      workspaces.map((w) => w.category).whereType<String>().toSet();
  final repository = ref.read(workspaceRepositoryProvider);

  for (final category in SystemWorkspaceCategory.all) {
    if (existingCategories.contains(category)) continue;
    final meta = WorkspaceCategoryMeta.of(category)!;
    await repository.createWorkspace(
      name: meta.label,
      icon: 'folder',
      description: meta.description,
      category: category,
    );
  }
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

  /// Rinomina/personalizza un Workspace esistente — anche una sezione fissa
  /// (rinominabile, ma non eliminabile: vedi [delete]). Non si chiama
  /// `update` per non collidere con `AsyncNotifier.update` ereditato.
  Future<Failure?> updateWorkspace(Workspace workspace) async {
    state = const AsyncLoading();
    final result =
        await ref.read(workspaceRepositoryProvider).updateWorkspace(workspace);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }

  /// "Elimina" un Workspace libero dell'utente (soft delete, Domain Model —
  /// "Le eliminazioni sono logiche"). Le sezioni fisse non esporre mai questa
  /// azione in UI ([WorkspaceCategoryMeta.isSystem]).
  Future<Failure?> delete(String workspaceId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(workspaceRepositoryProvider)
        .archiveWorkspace(workspaceId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
