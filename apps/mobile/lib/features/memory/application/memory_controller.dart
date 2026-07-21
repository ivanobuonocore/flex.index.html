import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_domain/pip_domain.dart';
import 'package:pip_shared/pip_shared.dart';

import '../../../core/providers.dart';

/// Memorie globali dell'utente corrente, in tempo reale (Software
/// Architecture, "Sincronizzazione" — Realtime lato Supabase).
final globalMemoriesProvider = StreamProvider.autoDispose<List<Memory>>(
  (ref) => ref.watch(memoryRepositoryProvider).watchGlobalMemories(),
);

final memoryFormControllerProvider =
    AsyncNotifierProvider.autoDispose<MemoryFormController, void>(
        MemoryFormController.new);

/// Prima slice minima (richiesta esplicita dell'utente): l'unica azione
/// dell'utente sulle Memorie è cancellarle — la creazione è solo lato AI
/// (vedi tool `remember_fact` in `ai-chat`), coerente con
/// [MemoryRepository] che non espone alcun metodo di creazione manuale.
class MemoryFormController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Failure?> delete(String memoryId) async {
    state = const AsyncLoading();
    final result =
        await ref.read(memoryRepositoryProvider).deleteMemory(memoryId);
    state = const AsyncData(null);
    return result.fold((_) => null, (failure) => failure);
  }
}
