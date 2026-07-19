# apps/mobile

App Flutter principale (MVP). Architettura Feature First: ogni feature sotto
`lib/features/<nome>/` con sottocartelle `presentation/ application/ domain/ data/`
(solo quelle necessarie — vedi AI Engineering Playbook).

State management: Riverpod. Routing: GoRouter (`StatefulShellRoute.indexedStack` per la
Bottom Navigation a 5 sezioni).

## Stato

Implementate, con dati reali via Supabase:

- **auth** (Fase 1) — login, registrazione, sessione, logout.
- **workspace** (Fase 1 + Fase 2 slice 1) — lista, creazione, Home del Workspace
  (`/workspace/:id`) con anteprima Note/Task e menu verso le sezioni non ancora
  implementate.
- **note** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/notes`), realtime.
- **task** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/tasks`), realtime,
  toggle rapido todo↔done.
- **today** (Fase 1) — saluto, Workspace recenti.

Strutturate e navigabili, in attesa delle rispettive fasi della roadmap
(`docs/product/26-execution-blueprint.md`):

- **chat** — Fase 3 (richiede l'AI Engine).
- **search** — richiede contenuti indicizzabili di più feature (prossima slice di Fase 2).
- **profile** — identità account e logout ora; abbonamento, tema, memoria, privacy nelle fasi
  successive.

Non ancora presenti: documents (prossima slice di Fase 2, richiede Supabase Storage),
memory, settings, billing.

## Setup locale

```
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=<url progetto> \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Schema database e policy RLS: vedi `infrastructure/supabase/`.

## Test

```
flutter test
```
