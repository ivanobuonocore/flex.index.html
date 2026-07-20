import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';
import 'workspace_category_meta.dart';

/// Workspace dell'utente autenticato, in tempo reale (Software Architecture,
/// "Sincronizzazione" — Realtime lato Supabase). Filtra eventuali sezioni
/// fisse duplicate ([_dedupeSystemWorkspaces]) — un fix, non solo una
/// difesa: senza l'indice unico di database (mai applicato a un progetto
/// Supabase reale in questa sessione, vedi apps/mobile/README.md, "Limiti
/// noti"), il bootstrap ha potuto inserire più righe con la stessa
/// categoria a ogni ricarica dell'app prima che l'indice esistesse
/// davvero — bug segnalato dall'utente ("ci sono più categorie di
/// appuntamenti").
final workspacesProvider = StreamProvider.autoDispose<List<Workspace>>((ref) {
  return ref
      .watch(workspaceRepositoryProvider)
      .watchWorkspaces()
      .map(_dedupeSystemWorkspaces);
});

/// Tiene solo la sezione fissa più vecchia per categoria (presumibilmente
/// quella già in uso, se un duplicato ha mai accumulato dati collegati);
/// i Workspace liberi non sono mai toccati — la firma "una categoria di
/// sistema per utente" vale solo per le 4 sezioni fisse, non per i
/// Workspace che l'utente crea liberamente (possono benissimo avere lo
/// stesso nome). Non elimina le righe duplicate dal database (richiede la
/// migrazione, vedi `infrastructure/supabase/migrations/
/// 20260720140000_workspace_system_category_unique.sql`): questa funzione
/// evita solo che l'utente le veda, finché quella migrazione non è stata
/// applicata.
List<Workspace> _dedupeSystemWorkspaces(List<Workspace> workspaces) {
  final earliestPerCategory = <String, Workspace>{};
  for (final workspace in workspaces) {
    final category = workspace.category;
    if (category == null || !SystemWorkspaceCategory.all.contains(category)) {
      continue;
    }
    final current = earliestPerCategory[category];
    if (current == null || workspace.createdAt.isBefore(current.createdAt)) {
      earliestPerCategory[category] = workspace;
    }
  }
  final keptSystemIds = earliestPerCategory.values.map((w) => w.id).toSet();

  return workspaces.where((workspace) {
    final category = workspace.category;
    final isSystem =
        category != null && SystemWorkspaceCategory.all.contains(category);
    return !isSystem || keptSystemIds.contains(workspace.id);
  }).toList(growable: false);
}

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
