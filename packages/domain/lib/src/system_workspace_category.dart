/// Chiavi di [Workspace.category] per le sezioni fisse (Fase 3, "Sezioni
/// fisse" — richiesta esplicita dell'utente: Bilancio/Appuntamenti/Attività/
/// Documenti sempre presenti per ogni utente, popolate dalla Chat, non
/// create manualmente). Un Workspace con una di queste categorie è una
/// sezione di sistema: rinominabile ma non eliminabile.
abstract final class SystemWorkspaceCategory {
  static const bilancio = 'bilancio';
  static const appuntamenti = 'appuntamenti';
  static const attivita = 'attivita';
  static const documenti = 'documenti';

  static const all = [bilancio, appuntamenti, attivita, documenti];
}
