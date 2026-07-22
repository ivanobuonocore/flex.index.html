import 'package:pip_shared/pip_shared.dart';

import '../entities/memory.dart';

/// Confine verso la persistenza delle Memorie, implementato nel layer `data`
/// di ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
///
/// Livello Globale (`MemoryLevel.global`): scritto solo dall'AI Engine
/// ("ricorda che..."), nessun metodo di creazione qui. Livello Workspace
/// (`MemoryLevel.workspace`): creato manualmente dall'utente — "Chat unica"
/// ha reso la Chat un'unica conversazione globale per utente, non più
/// scopata a un singolo Workspace, quindi l'AI Engine non ha modo di sapere
/// a quale Workspace collegare un ricordo pronunciato in Chat. Livello
/// Conversazione: fuori scope, per lo stesso motivo in forma più radicale —
/// con un'unica conversazione per utente coinciderebbe sempre col Globale.
abstract interface class MemoryRepository {
  /// Memorie globali dell'utente corrente, più recenti per prime.
  Stream<List<Memory>> watchGlobalMemories();

  /// Memorie di un Workspace specifico, più recenti per prime.
  Stream<List<Memory>> watchWorkspaceMemories(String workspaceId);

  /// Crea una memoria di livello Workspace, inserita manualmente dall'utente
  /// (origine `MemoryOrigin.user`, a differenza del Globale che è solo AI).
  Future<Result<Memory>> createWorkspaceMemory({
    required String workspaceId,
    required String content,
  });

  /// Soft/hard delete della memoria (AI Constitution, trasparenza: l'utente
  /// deve poter sempre cancellare cosa l'AI — o lui stesso — ricorda).
  Future<Result<Unit>> deleteMemory(String memoryId);
}
