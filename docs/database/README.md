# docs/database

Documentazione dello schema database. Le migrazioni eseguibili vivono in
`infrastructure/supabase/migrations/`; questo documento ne spiega le decisioni.

## Fase 1 — Foundation

### `public.workspaces`

Persistenza dell'entità Workspace (`docs/product/12-domain-model.md`).

| Colonna       | Tipo          | Note                                              |
|---------------|---------------|----------------------------------------------------|
| `id`          | `uuid`        | Chiave primaria, `gen_random_uuid()` (v4)          |
| `owner_id`    | `uuid`        | FK verso `auth.users`, non nullo                    |
| `name`        | `text`        | Non nullo, non vuoto (constraint)                   |
| `description` | `text`        | Facoltativo                                          |
| `icon`        | `text`        | Non nullo, default `'folder'`                       |
| `category`    | `text`        | Facoltativo                                          |
| `status`      | `text`        | `active` / `archived` (check constraint)             |
| `color`       | `text`        | Facoltativo                                          |
| `created_at`  | `timestamptz` | Default `now()`                                      |
| `deleted_at`  | `timestamptz` | Soft delete (Domain Model, "Principi del modello")  |

**Sicurezza**: Row Level Security abilitata, quattro policy (`select`/`insert`/`update`/`delete`)
che confrontano `auth.uid()` con `owner_id`. Nessun utente può leggere o scrivere Workspace di cui
non è proprietario — verificato manualmente (vedi `infrastructure/supabase/README.md`).

**Decisioni prese rispetto ai documenti di prodotto**:

- **ID UUID v4, non v7** — l'AI Engineering Playbook richiede UUID v7 per gli ID dei Workspace,
  ma Supabase non offre un generatore v7 nativo pronto all'uso. `gen_random_uuid()` (v4) è lo
  standard supportato; il tipo di colonna (`uuid`) resta compatibile con una futura migrazione a
  v7 senza modifiche allo schema.
- **Nessuna tabella `profiles`** — in Fase 1 `User.plan`/`name` sono derivati da
  `auth.users.user_metadata` lato client (vedi `SupabaseAuthRepository` in `apps/mobile`). Una
  tabella `profiles` dedicata verrà introdotta quando emergerà un bisogno reale di dati utente
  interrogabili lato server (es. Billing, Fase 5/6), per evitare una tabella senza scopo concreto.

## Fase 2 (slice 1) — Note e Task

### `public.notes` / `public.tasks`

Persistenza delle entità Note e Task (`docs/product/12-domain-model.md`). Entrambe referenziano
`workspace_id uuid references public.workspaces (id) on delete cascade`.

| Tabella | Colonne specifiche                                                                 |
|---------|-------------------------------------------------------------------------------------|
| `notes` | `title`, `content` (default `''`), `tags text[]`, `created_by_ai`, `updated_at`      |
| `tasks` | `title`, `description`, `status` (`todo`/`in_progress`/`done`), `priority` (`low`/`medium`/`high`), `due_at`, `assignee_id`, `generated_by_ai`, `document_id`, `chat_id`, `created_at` |

Entrambe hanno `deleted_at` (soft delete) e vincolo `title` non vuoto.

**Sicurezza — differenza rispetto a `workspaces`**: `notes`/`tasks` non hanno una colonna
`owner_id` propria. Le policy RLS verificano l'appartenenza tramite `EXISTS` sul Workspace
referenziato (`w.owner_id = auth.uid()`), coerente con "ogni risorsa appartiene a un Workspace,
il Workspace è il confine logico" (Architectural Principles, Principio 3). Verificato
manualmente: select/insert/update/delete cross-Workspace tutti bloccati (vedi
`infrastructure/supabase/README.md`).

**`assignee_id`/`document_id`/`chat_id` senza FK verso Document/Chat**: quelle tabelle non
esistono ancora (arrivano con Documenti e Chat, prossime slice di Fase 2 e Fase 3); i campi
restano come riferimenti applicativi finché le tabelle corrispondenti non vengono create.

## Fase 2 (slice 2) — Documenti

### `public.documents`

Persistenza dell'entità Document (`docs/product/12-domain-model.md`): `workspace_id`, `name`,
`mime_type`, `size_bytes`, `storage_path` (univoco), `hash` (SHA-256, deduplicazione), `chat_id`,
`uploaded_at`, `deleted_at`. Stesso pattern RLS a join di `notes`/`tasks`.

**Prima migrazione che tocca Supabase Storage**, non solo Postgres: bucket `documents` (privato —
l'accesso passa sempre da signed URL, mai da un URL pubblico diretto) e tre policy su
`storage.objects` che replicano lo stesso controllo di appartenenza al Workspace, applicato al
primo segmento del path dell'oggetto (`storage.foldername(objects.name)[1]`, convenzione di path
`{workspace_id}/{timestamp}_{filename}` scelta in `SupabaseDocumentRepository`).

**Bug trovato e corretto durante la verifica manuale**: la prima versione della policy usava
`storage.foldername(name)` senza qualificare `name` — dentro la subquery `EXISTS`, `name` è
ambiguo tra la colonna dell'oggetto Storage (quella intesa) e `workspaces.name` (la tabella
referenziata ha anch'essa una colonna `name`), e Postgres lo risolveva verso quest'ultima.
Risultato: la policy negava anche gli upload legittimi. Corretto qualificando esplicitamente
`objects.name`. Verificato su un Postgres locale con uno schema `storage` fittizio
(`storage.objects`, `storage.foldername()`) creato per l'occasione — non è Supabase Storage
reale, ma la stessa logica SQL, ed è quanto basta per aver individuato il bug.

**Non verificabile in locale**: il comportamento completo di Supabase Storage (upload reale,
generazione di signed URL) richiede `supabase start` (Docker) o un progetto remoto — non
disponibili in questa sessione.

## Fasi successive

Chat, Message, Memory, Agent, Calendar Event, Timeline Event sono già modellate in
`packages/domain` ma non hanno ancora una migrazione: arriveranno con le rispettive feature
(Fase 2 — prossime slice, Fase 3 — AI Layer; `docs/product/26-execution-blueprint.md`).

Note tecniche aperte dal Domain Model, da risolvere prima di quelle migrazioni:

- `workspace_agents` come tabella di giunzione per la relazione many-to-many Agent↔Workspace.
- Vincolo di coerenza tra `Memory.level` e l'owner valorizzato (già applicato lato dominio in
  `packages/domain/lib/src/entities/memory.dart` con un `assert`; da replicare come `check`
  constraint quando la tabella verrà creata).
- Pattern polimorfico `entity_type` + `entity_id` per `Timeline Event`.
