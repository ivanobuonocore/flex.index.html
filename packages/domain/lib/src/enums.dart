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
