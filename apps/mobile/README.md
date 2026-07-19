# apps/mobile

App Flutter principale (MVP). Architettura Feature First: ogni feature sotto
`lib/features/<nome>/` con sottocartelle `presentation/ application/ domain/ data/`
(solo quelle necessarie — vedi AI Engineering Playbook).

State management: Riverpod. Routing: GoRouter (`StatefulShellRoute.indexedStack` per la
Bottom Navigation a 5 sezioni).

## Stato

Implementate, con dati reali via Supabase:

- **auth** (Fase 1) — login, registrazione, sessione, logout.
- **workspace** (Fase 1 + Fase 2 slice 1/2) — lista, creazione, Home del Workspace
  (`/workspace/:id`) con anteprima Note/Task/Documenti e menu verso le sezioni non ancora
  implementate.
- **note** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/notes`), realtime.
- **task** (Fase 2 slice 1) — CRUD completo per Workspace (`/workspace/:id/tasks`), realtime,
  toggle rapido todo↔done.
- **document** (Fase 2 slice 2) — upload/apertura/eliminazione per Workspace
  (`/workspace/:id/documents`), Supabase Storage con signed URL, realtime.
- **search** (Fase 2 slice 3) — Ricerca Universale cross-tabella (Workspace/Note/Task/
  Documenti) via full-text search Postgres, debounce lato UI.
- **today** (Fase 1) — saluto, Workspace recenti.

Strutturate e navigabili, in attesa delle rispettive fasi della roadmap
(`docs/product/26-execution-blueprint.md`):

- **chat** — Fase 3 (richiede l'AI Engine).
- **profile** — identità account e logout ora; abbonamento, tema, memoria, privacy nelle fasi
  successive.

Non ancora presenti: memory, settings, billing.

## Limiti noti (dichiarati, non nascosti)

- Questo modulo non ha mai eseguito `flutter create`: non esistono le cartelle piattaforma
  (`android/`, `ios/`, `web/`, ...). `flutter analyze`/`flutter test` funzionano (analisi Dart
  pura), ma l'app non è ancora eseguibile su un device/emulatore reale.
- `file_picker` (selezione file) e l'apertura effettiva di un URL con `url_launcher` non sono
  testabili in questo ambiente (nessun canale di piattaforma nativo): la logica di dominio e i
  repository sono comunque coperti da test con repository fake (`document_controller_test.dart`).

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
