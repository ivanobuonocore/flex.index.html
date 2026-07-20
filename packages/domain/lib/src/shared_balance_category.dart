/// Valore di [Workspace.category] per un Bilancio condiviso (Fase 3,
/// "Bilancio condiviso"): un Workspace libero creato esplicitamente
/// dall'utente per essere condiviso con un'altra persona — distinto sia
/// dalle 4 sezioni fisse ([SystemWorkspaceCategory], auto-create, uniche per
/// utente) sia dai normali Workspace liberi senza categoria. Serve solo a
/// far comparire questi Workspace nella schermata dedicata
/// (`SharedBalanceScreen`, `apps/mobile`), non introduce nessuna sezione
/// fissa né logica di bootstrap.
const sharedBalanceCategory = 'bilancio_condiviso';
