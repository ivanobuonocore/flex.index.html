import 'package:pip_shared/pip_shared.dart';

import '../entities/memory.dart';

/// Confine verso la persistenza delle Memorie, implementato nel layer `data`
/// di ogni app (Dependency Inversion — Engineering Constitution, Articolo 4).
///
/// Prima slice minima (richiesta esplicita dell'utente): solo il livello
/// globale (`MemoryLevel.global`, legato all'utente) — Workspace e
/// Conversazione arriveranno con le rispettive feature.
abstract interface class MemoryRepository {
  /// Memorie globali dell'utente corrente, più recenti per prime.
  Stream<List<Memory>> watchGlobalMemories();

  /// Soft/hard delete della memoria (AI Constitution, trasparenza: l'utente
  /// deve poter sempre cancellare cosa l'AI ricorda di lui).
  Future<Result<Unit>> deleteMemory(String memoryId);
}
