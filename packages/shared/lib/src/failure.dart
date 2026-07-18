/// Errore di dominio applicativo, mai un'eccezione tecnica grezza esposta all'utente
/// (Engineering Constitution, Articolo 6; AI Engineering Playbook, "Error Handling").
sealed class Failure {
  const Failure(this.message, {this.cause});

  /// Messaggio comprensibile all'utente. Mai stack trace o dettagli tecnici.
  final String message;

  /// Causa tecnica originale, solo per logging.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Credenziali non valide o sessione assente/scaduta.
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

/// L'utente ha tentato di accedere a una risorsa fuori dal proprio Workspace
/// (Architectural Principles, Principio 3 — isolamento dei Workspace).
final class WorkspaceAccessFailure extends Failure {
  const WorkspaceAccessFailure(super.message, {super.cause});
}

/// Input non valido, rifiutato prima di raggiungere il livello dati.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

/// Errore di rete, timeout, servizio remoto non raggiungibile.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

/// Errore non atteso, non riconducibile alle categorie precedenti.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}
