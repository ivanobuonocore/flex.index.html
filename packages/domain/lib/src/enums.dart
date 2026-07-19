/// Piano di abbonamento dell'utente (Domain Model, entità User).
enum UserPlan { free, pro, business }

/// Stato di un Workspace (Domain Model, entità Workspace).
enum WorkspaceStatus { active, archived }

/// Stato di una conversazione (Domain Model, entità Chat).
enum ChatStatus { active, archived }

/// Autore di un messaggio all'interno di una Chat (Domain Model, entità Message).
enum MessageRole { user, ai, system }

/// Stato di avanzamento di una Task (Domain Model, entità Task).
enum TaskStatus { todo, inProgress, done }

/// Priorità di una Task (Domain Model, entità Task).
enum TaskPriority { low, medium, high }

/// Livello di una Memoria: a chi/cosa è associata (Domain Model, entità Memory;
/// Software Architecture, "Memoria AI — tre livelli").
enum MemoryLevel { global, workspace, conversation }

/// Chi ha generato una Memoria (Domain Model, entità Memory).
enum MemoryOrigin { user, ai }

/// Tipo di contenuto trovato dalla Ricerca Universale
/// (docs/product/06-information-architecture.md, "Ricerca").
enum SearchResultType { workspace, note, task, document }

/// Stato di conferma di una Transazione (Domain Model, entità Transaction).
/// Le transazioni suggerite dall'AI restano "pending" finché l'utente non le
/// conferma esplicitamente (AI Constitution, Principio 1 — "l'AI può
/// suggerire, l'utente decide").
enum TransactionStatus { pending, confirmed }

/// Entrata o uscita (Domain Model, entità Transaction). `amountCents` resta
/// sempre positivo: è questo campo a determinare il segno nel bilancio.
enum TransactionType { income, expense }
