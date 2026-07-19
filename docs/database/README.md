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

## Fase 2 (slice 3) — Ricerca Universale

### `public.search_workspace_content(query text)`

Funzione SQL (`language sql`, `stable`) che unisce con `UNION ALL` risultati full-text da
`workspaces`, `notes`, `tasks`, `documents` — non è una tabella, è un read-model derivato
(`SearchResult` lato dominio). Indici GIN su `to_tsvector('simple', ...)` per ciascuna tabella
(config `simple`: nessuno stemming linguistico, i contenuti dell'utente non sono garantiti in
una sola lingua).

**Sicurezza — `security invoker` esplicito**: la funzione gira con i privilegi di chi chiama,
quindi le policy RLS di ciascuna tabella si applicano automaticamente alle `SELECT` al suo
interno. Non c'è nessun filtro `owner_id`/`EXISTS` duplicato dentro la funzione: l'isolamento
dipende interamente da questo meccanismo. **Verificato manualmente** con due utenti/due
Workspace: ciascuno vede solo i propri risultati tramite la funzione, esattamente come le
tabelle sottostanti.

**Bug di qualità trovato e corretto durante la verifica** (non di sicurezza): i nomi file
generati da `SupabaseDocumentRepository` contengono `_` (sanitizzazione dei caratteri non
alfanumerici). Il parser `simple` di Postgres tratta `contratto_alfa.pdf` come un unico
lessema, quindi cercare "contratto" non trovava il documento. Corretto normalizzando `_`/`.` in
spazi prima della tokenizzazione (`regexp_replace(name, '[_.]', ' ', 'g')`), sia nell'indice sia
nella funzione. Verificato: senza la normalizzazione il documento non compariva tra i
risultati, con la normalizzazione sì.

## Fase 3 (slice 1) — AI Engine + Chat

### `public.chats` / `public.messages`

Persistenza delle entità Chat e Message (`docs/product/12-domain-model.md`).

| Tabella    | Colonne specifiche                                                                          |
|------------|------------------------------------------------------------------------------------------------|
| `chats`    | `owner_id`, `workspace_id` (nullable), `title`, `ai_model`, `status` (`active`/`archived`), `created_at`, `last_message_at` |
| `messages` | `chat_id`, `role` (`user`/`ai`/`system`), `content`, `attachment_ids text[]`, `tokens_used`, `source_references text[]`, `created_at` |

**Sicurezza — `chats` torna a `owner_id` diretto, non a join**: a differenza di `notes`/`tasks`,
una Chat può esistere senza Workspace (Domain Model — Chat privata), quindi non può isolarsi solo
tramite `EXISTS` su un Workspace che potrebbe non esserci. Le policy RLS confrontano `owner_id =
auth.uid()`, stesso pattern di `workspaces`. `messages` invece non ha una colonna proprietario: le
policy verificano l'appartenenza tramite `EXISTS` sulla Chat referenziata (`c.owner_id =
auth.uid()`), pattern identico a `notes`/`tasks` verso `workspaces`.

**Trigger `touch_chat_last_message()`**: `after insert on messages`, `security invoker`,
aggiorna `chats.last_message_at` — evita un secondo round-trip dal client solo per quello.
Verificato manualmente su Postgres locale.

**Verificato manualmente**: insert di un messaggio su una Chat di un altro utente bloccato da
RLS; il trigger aggiorna correttamente `last_message_at`; un secondo utente non vede i messaggi
del primo.

### Edge Function `ai-chat`

L'AI Engine (Architectural Principles: "mai il frontend collegato direttamente a un provider
LLM") vive come Supabase Edge Function, non come servizio separato —
`infrastructure/supabase/functions/ai-chat/index.ts`. Il client Supabase creato dentro la function
inoltra il JWT di chi chiama (mai la service role key): le stesse policy RLS di
`chats`/`messages`/`notes`/`tasks`/`documents` si applicano anche lì, stesso principio
`security invoker` già usato per `search_workspace_content` — la function non ha modo di leggere
dati di un Workspace che l'utente non possiede.

Costruisce il contesto per euristica (per recency, non ricerca semantica): fino a 5 tra
Note/Task/Documenti più recenti del Workspace, più lo storico degli ultimi 20 messaggi della
Chat. Chiama `https://api.anthropic.com/v1/messages` (chiave in `ANTHROPIC_API_KEY`, secret
Supabase — mai nel codice, vedi `infrastructure/supabase/README.md`). La risposta viene inserita
come riga `messages` (`role: 'ai'`) con `source_references` valorizzato dagli id delle
Note/Task/Documenti effettivamente incluse nel contesto (trasparenza richiesta da
`docs/product/21-ai-constitution.md`, Principio 3).

**Non verificabile in questa sessione**: nessuna chiamata reale a `api.anthropic.com` (nessuna
chiave disponibile) né alla Edge Function stessa tramite Supabase Functions runtime (richiede
`supabase start` con Docker o un progetto remoto). Verificato invece quello che è realmente
verificabile: il codice TypeScript con `deno check`/`deno lint`/`deno fmt --check` (Deno
installato in sessione), tutti puliti.

## Fase 3 (slice 2) — Spese

Aggiunta oltre allo scaffold originale: richiesta reale dell'utente ("scrivo le spese in chat,
voglio vedere il totale"), non descritta in `docs/product/26-execution-blueprint.md`. Non viola
i principi architetturali (Workspace resta il confine, l'AI Engine resta l'unico punto di
contatto col provider) — vedi anche `docs/product/12-domain-model.md`, entità `Expense`.

### `public.expenses`

| Colonna         | Note                                                                        |
|-----------------|--------------------------------------------------------------------------------|
| `workspace_id`  | FK cascade, obbligatorio — una spesa non esiste senza Workspace                |
| `chat_id`       | FK set null, nullable — valorizzato solo se estratta dall'AI Engine da una Chat |
| `description`   | non vuota (constraint)                                                         |
| `amount_cents`  | intero, `> 0` (constraint) — mai un float, per evitare errori di somma         |
| `currency`      | default `'EUR'` (solo EUR gestito in questa slice)                             |
| `occurred_at`   | data della spesa                                                               |
| `status`        | `pending` / `confirmed`, default `confirmed`                                   |
| `created_by_ai` | `true` solo per le spese inserite dalla Edge Function `ai-chat`                |

Stesso pattern RLS a join di `notes`/`tasks`/`documents` (`EXISTS` su
`workspaces.owner_id = auth.uid()`). Indice composito `(workspace_id, occurred_at desc)` per
l'aggregazione mensile nella schermata Spese (calcolata lato client su questa slice, non con una
funzione SQL dedicata — scope volutamente ridotto).

**`status` e AI Constitution, Principio 1** ("l'AI può suggerire, l'utente decide"): le spese
inserite manualmente dall'utente nascono `confirmed` da subito (l'ha scritte deliberatamente);
quelle estratte dall'AI Engine nascono `pending` e contano nei totali della schermata Spese solo
dopo che l'utente le conferma esplicitamente.

**Estrazione lato Edge Function `ai-chat`**: quando la Chat ha un Workspace valido (verificato
tramite RLS, non solo per presenza del parametro), la function offre ad Anthropic uno strumento
(`tool use`) `extract_expenses` con uno schema JSON esplicito
(`description`, `amount_cents`, `occurred_at`); il modello decide autonomamente se e quando
usarlo (`tool_choice: "auto"`, nessuna forzatura). L'output dello strumento viene validato di
nuovo lato function (`sanitizeExpense`) prima dell'insert: lo schema JSON vincola la forma, non
la correttezza semantica dei valori. Stesso client autenticato col JWT del chiamante usato per
`messages` — nessun privilegio aggiuntivo.

**Verificato manualmente su Postgres locale**: isolamento cross-utente su `expenses` (select,
insert, update, delete tutti bloccati per un Workspace non proprio); constraint `amount_cents >
0` e descrizione non vuota entrambi verificati.

**Non verificabile in questa sessione**: come per il resto di `ai-chat`, nessuna chiamata reale
al provider Anthropic — il comportamento dello strumento `extract_expenses` (se il modello lo
usa correttamente, se risolve bene le date relative) non è testabile senza una chiave reale.
Verificato solo staticamente (`deno check`/`lint`/`fmt`).

## Fasi successive

Memory, Agent, Calendar Event, Timeline Event sono già modellate in `packages/domain` ma non
hanno ancora una migrazione: arriveranno con le rispettive feature (`docs/product/26-execution-blueprint.md`).

Note tecniche aperte dal Domain Model, da risolvere prima di quelle migrazioni:

- `workspace_agents` come tabella di giunzione per la relazione many-to-many Agent↔Workspace.
- Vincolo di coerenza tra `Memory.level` e l'owner valorizzato (già applicato lato dominio in
  `packages/domain/lib/src/entities/memory.dart` con un `assert`; da replicare come `check`
  constraint quando la tabella verrà creata).
- Pattern polimorfico `entity_type` + `entity_id` per `Timeline Event`.
