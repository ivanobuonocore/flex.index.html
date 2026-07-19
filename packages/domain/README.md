# packages/domain

Modello di dominio (vedi docs/product/12-domain-model.md), indipendente da Flutter,
Supabase o da qualsiasi provider AI (Engineering Handbook, Principio 1 / Articolo 1).

## Contenuto

- `src/entities/`: User, Workspace, Chat, Message, Document, Task, Note, Memory, Agent,
  CalendarEvent, TimelineEvent — classi immutabili, senza dipendenze esterne. `SearchResult` è
  l'eccezione: non un'entità del Domain Model originale, ma un read-model derivato da una query
  cross-tabella (Ricerca Universale).
- `src/repositories/`: interfacce (`AuthRepository`, `WorkspaceRepository`, `NoteRepository`,
  `TaskRepository`, `DocumentRepository`, `SearchRepository`, `ChatRepository`,
  `MessageRepository`) implementate nel layer `data` di ogni app, per Dependency Inversion
  (Engineering Constitution, Articolo 4).
- `src/enums.dart`: enumerazioni condivise tra le entità.

## Stato

Auth, Workspace, Note, Task, Document, Ricerca Universale e Chat hanno un'implementazione
concreta lato app (`apps/mobile`), verificata anche a livello di schema/RLS
(`infrastructure/supabase`). Memory, Agent, CalendarEvent, TimelineEvent restano solo modellate,
pronte per le fasi successive della roadmap (`docs/product/26-execution-blueprint.md`) senza
richiedere modifiche al modello.

## Test

```
cd packages/domain && dart pub get && dart test
```
