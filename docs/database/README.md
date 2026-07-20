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

**`chat_id` (Fase 3 slice 2)**: colonna presente fin dallo scaffold originale ma popolata solo a
partire dalla feature "foto nei messaggi di Chat" — un documento con `chat_id` valorizzato è una
foto allegata a un messaggio (`Message.attachmentIds`), non un documento della sezione Documenti
del Workspace. Stessa tabella, stesso bucket, nessuna nuova migrazione: solo un nuovo modo di
popolare una colonna già esistente.

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

## Fase 3 (slice 2) — Bilancio (entrate e uscite)

Aggiunta oltre allo scaffold originale: richiesta reale dell'utente ("scrivo le spese in chat,
voglio vedere il totale", poi estesa a "rendi l'app simile a Planito" — un assistente su WhatsApp
con contabilità in linguaggio naturale), non descritta in `docs/product/26-execution-blueprint.md`.
Non viola i principi architetturali (Workspace resta il confine, l'AI Engine resta l'unico punto
di contatto col provider) — vedi anche `docs/product/12-domain-model.md`, entità `Transaction`.
Generalizza la prima versione, che copriva solo le uscite, in un'unica tabella con un campo
`type` invece di un'entità separata per le entrate — evita di duplicare schema/RLS/repository per
una struttura dati quasi identica.

### `public.transactions`

| Colonna         | Note                                                                              |
|-----------------|----------------------------------------------------------------------------------|
| `workspace_id`  | FK cascade, obbligatorio — una transazione non esiste senza Workspace            |
| `chat_id`       | FK set null, nullable — valorizzato solo se estratta dall'AI Engine da una Chat  |
| `type`          | `income` / `expense` (constraint) — decide il segno nel saldo                    |
| `description`   | non vuota (constraint)                                                           |
| `amount_cents`  | intero, `> 0` (constraint) — sempre positivo, mai un float, per evitare errori di somma |
| `currency`      | default `'EUR'` (solo EUR gestito in questa slice)                               |
| `occurred_at`   | data della transazione                                                           |
| `status`        | `pending` / `confirmed`, default `confirmed`                                     |
| `created_by_ai` | `true` solo per le transazioni inserite dalla Edge Function `ai-chat`            |

Stesso pattern RLS a join di `notes`/`tasks`/`documents` (`EXISTS` su
`workspaces.owner_id = auth.uid()`). Indice composito `(workspace_id, occurred_at desc)` per
l'aggregazione mensile nella schermata Bilancio (calcolata lato client su questa slice, non con
una funzione SQL dedicata — scope volutamente ridotto).

**`status` e AI Constitution, Principio 1** ("l'AI può suggerire, l'utente decide"): le
transazioni inserite manualmente dall'utente nascono `confirmed` da subito (le ha scritte
deliberatamente); quelle estratte dall'AI Engine nascono `pending` e contano nel saldo della
schermata Bilancio solo dopo che l'utente le conferma esplicitamente.

**Estrazione lato Edge Function `ai-chat`**: quando la Chat ha un Workspace valido (verificato
tramite RLS, non solo per presenza del parametro), la function offre ad Anthropic uno strumento
(`tool use`) `extract_transactions` con uno schema JSON esplicito
(`type`, `description`, `amount_cents`, `occurred_at`); il modello decide autonomamente se e
quando usarlo (`tool_choice: "auto"`, nessuna forzatura), riconoscendo sia spese sia entrate
(es. "ho ricevuto lo stipendio di 1500€"). L'output dello strumento viene validato di nuovo lato
function (`sanitizeTransaction`) prima dell'insert: lo schema JSON vincola la forma, non la
correttezza semantica dei valori. Stesso client autenticato col JWT del chiamante usato per
`messages` — nessun privilegio aggiuntivo.

**Verificato manualmente su Postgres locale**: isolamento cross-utente su `transactions` (select,
insert, update, delete tutti bloccati per un Workspace non proprio); constraint `type`,
`amount_cents > 0` e descrizione non vuota tutti verificati; calcolo del saldo (entrate − uscite,
solo `confirmed`) verificato con dati misti.

**Non verificabile in questa sessione**: come per il resto di `ai-chat`, nessuna chiamata reale
al provider Anthropic — il comportamento dello strumento `extract_transactions` (se il modello lo
usa correttamente, se distingue bene entrate/uscite, se risolve bene le date relative) non è
testabile senza una chiave reale. Verificato solo staticamente (`deno check`/`lint`/`fmt`).

## Fase 3 (slice 3) — Foto nei messaggi di Chat

Nessuna nuova tabella: riusa `public.documents` e il bucket Storage `documents` esistenti
(vedi sopra, "`chat_id` (Fase 3 slice 2)"). Una foto allegata a un messaggio è un `Document` con
`chat_id` valorizzato; il suo id viene referenziato in `Message.attachmentIds` (colonna già
presente dallo scaffold originale, mai popolata fino a questa slice).

**Edge Function `ai-chat`**: solo l'**ultimo messaggio dell'utente** (non l'intera cronologia, per
contenere costo/latenza) può includere immagini nella chiamata ad Anthropic. Se ha
`attachment_ids`, la function legge `storage_path`/`mime_type` da `documents` (stesso client
JWT-scoped, stesse RLS/policy Storage già verificate per la sezione Documenti — nessun privilegio
aggiuntivo), scarica i byte e li converte in un blocco immagine Anthropic (`type: "image", source:
{type: "base64", ...}`). Massimo 3 immagini per messaggio, ciascuna scartata silenziosamente
(turno comunque proseguito con testo + immagini valide) se supera ~5MB o non è scaricabile. La
codifica base64 è scritta a mano nella function stessa, senza dipendenze esterne — evita lo stesso
problema già incontrato con `jsr:` irraggiungibile nella rete di verifica di questo sandbox.

**Limite noto**: Anthropic supporta ufficialmente immagini JPEG/PNG/GIF/WebP. `apps/mobile`
permette di scegliere qualunque immagine dalla libreria (inclusi formati come HEIC, comune su
iPhone): un'immagine in un formato non supportato non causa un crash, ma il turno può fallire con
l'errore generico già gestito ("Il servizio AI non è disponibile al momento") — non verificabile
senza chiave Anthropic reale.

**Non verificabile in questa sessione**: come per il resto di `ai-chat`, nessuna chiamata reale al
provider Anthropic — se il modello interpreta correttamente le immagini non è testabile senza una
chiave reale. Verificato solo staticamente (`deno check`/`lint`/`fmt`).

## Fase 3 (slice 4) — Notifiche push vere

### `public.push_subscriptions`

Prima slice delle notifiche push vere (CLAUDE.md — richiesta esplicita dell'utente, che ha
rifiutato l'alternativa "elenco prossimi promemoria in app" per volere invece notifiche di sistema
reali). Livello **account, non Workspace** — una notifica non appartiene a un singolo Workspace,
stesso pattern `owner_id` diretto di `workspaces`/`chats`, non un join come `notes`/`tasks`.

| Colonna      | Tipo          | Note                                                        |
|--------------|---------------|---------------------------------------------------------------|
| `id`         | `uuid`        | Chiave primaria                                                |
| `user_id`    | `uuid`        | FK diretta `auth.users`, non nullo                              |
| `endpoint`   | `text`        | Univoco — identifica il dispositivo/browser abbonato            |
| `p256dh`     | `text`        | Chiave pubblica della sottoscrizione (Web Push, RFC 8291)        |
| `auth_key`   | `text`        | Segreto di autenticazione della sottoscrizione                   |
| `created_at` | `timestamptz` | Default `now()`                                                 |

**Sicurezza**: RLS diretta su `auth.uid() = user_id`, quattro policy (select/insert/update/delete).
Verificato manualmente su Postgres locale: isolamento cross-utente su tutte e quattro le
operazioni, oltre ai constraint su campi non vuoti e sull'unicità di `endpoint`.

**Perché solo "infrastruttura + prova" e non ancora i Promemoria**: il collegamento
browser↔notifica (permessi, service worker, chiavi VAPID, cifratura Web Push) non era mai stato
costruito in questo progetto ed è verificabile solo in parte da questo ambiente (nessun browser
reale). Questa slice consegna la catena completa ma minima — un pulsante "Invia una notifica di
prova" in Profilo — per provarla per davvero prima di costruirci sopra i Promemoria
(`CalendarEvent`, già modellato in `packages/domain` ma non ancora implementato).

### Edge Function `send-test-push`

Non fa parte dell'AI Engine (nessuna chiamata ad Anthropic): legge le `push_subscriptions`
dell'utente che chiama (stesso client JWT-scoped delle altre function, mai la service role) e
invia una notifica di prova a ciascuna tramite `npm:web-push`. Le iscrizioni che risultano scadute
lato browser (risposta 404/410) vengono eliminate silenziosamente, non trattate come errore.
Richiede tre secrets aggiuntivi (`VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`) — vedi
`infrastructure/supabase/README.md`.

**Verificato**: `deno check`/`deno lint`/`deno fmt --check`, incluso che `npm:web-push@3` risolve
correttamente (registro npm raggiungibile in questa sessione, come già per `@supabase/supabase-js`).
**Non verificabile qui**: nessuna chiamata HTTP reale alla function (richiederebbe un progetto
Supabase remoto o Docker), né una notifica realmente recapitata a un browser.

## Fase 3 (slice 7A) — Sezioni fisse

Richiesta esplicita dell'utente ("vorrei che non fosse l'utente a gestire il workspace ma che
fosse la chat... i workspace predefiniti devono già comparire"): ogni utente ha 4 Workspace di
sistema — Bilancio/Appuntamenti/Attività/Documenti (`SystemWorkspaceCategory` in
`packages/domain`) — creati automaticamente (non da una migrazione/trigger, perché deve valere
anche per gli utenti già esistenti, non solo per le nuove registrazioni: vedi
`workspaceBootstrapProvider` in `apps/mobile`). Nessuna nuova tabella: riusa `workspaces.category`,
già presente dallo schema Fase 1 ma finora non popolato dall'app.

```sql
create unique index if not exists workspaces_owner_system_category_unique
  on public.workspaces (owner_id, category)
  where category in ('bilancio', 'appuntamenti', 'attivita', 'documenti')
    and deleted_at is null;
```

**Perché un indice e non solo il controllo lato app**: il bootstrap client-side è idempotente per
singola chiamata, ma due sessioni concorrenti (due tab aperte) potrebbero correre in parallelo —
l'indice unico parziale è l'unica vera garanzia contro sezioni duplicate (Architectural
Principles, Principio 9: la sicurezza/validazione non può dipendere solo dall'app). Una violazione
dell'indice fa fallire silenziosamente la sola `createWorkspace` di troppo (già gestita come
`UnexpectedFailure`, ignorata dal bootstrap): nessun crash, nessun duplicato visibile.

**`archiveWorkspace` ora imposta anche `deleted_at`** (prima impostava solo `status = 'archived'`,
lasciando il Workspace comunque visibile — un bug latente, mai stato collegato a un pulsante in
UI finché questa slice non ha aggiunto "Elimina" su `WorkspaceCard`): un Workspace "eliminato"
sparisce ora davvero da `watchWorkspaces()`, restando comunque solo archiviato (soft delete, non
una `DELETE` fisica) — coerente con Domain Model, "Le eliminazioni sono logiche". Le 4 sezioni
fisse non espongono questa azione in UI (strutturali, non eliminabili — solo rinominabili).

**Non verificabile qui**: nessun Postgres/Docker disponibile in questa sessione (stesso limite
delle slice precedenti) — l'indice non è stato eseguito contro un database reale, solo scritto e
riletto per correttezza sintattica.

## Fase 3 (slice 7C) — Bilancio con categorie

Richiesta esplicita dell'utente: una spesa come "barbiere" va classificata, non solo registrata.
Colonna aggiuntiva su `public.transactions` (non una nuova tabella — stesso pattern di
`workspaces.category`, Fase 3 slice 7A):

```sql
alter table public.transactions
  add column if not exists category text not null default 'altro'
    check (category in (
      'alimentari', 'trasporti', 'casa', 'bollette', 'salute',
      'svago', 'shopping', 'istruzione', 'stipendio', 'altro'
    ));
```

Set fisso di 10 categorie (`TransactionCategory` in `packages/domain`), non estensibile
dall'utente — coerente con le sezioni fisse: l'obiettivo è capire a colpo d'occhio dove va il
denaro, non costruire una tassonomia personalizzata. Default `'altro'` sia per le transazioni
esistenti (create prima di questa slice, quindi senza una categoria) sia per quelle nuove senza
una categoria più specifica.

**Estrazione lato Edge Function `ai-chat`**: lo schema JSON di `extract_transactions` guadagna un
campo `category` obbligatorio (stesso set di 10 valori, duplicato in TypeScript — nessuna
condivisione di tipi tra Dart e la Edge Function in questo progetto); il system prompt istruisce
il modello a classificare ogni transazione (es. "barbiere" → `svago`, "supermercato" →
`alimentari`, uno stipendio → `stipendio`). A differenza degli altri campi dello strumento, una
categoria mancante o non riconosciuta **non invalida** la transazione: `sanitizeTransaction`
ricade su `'altro'` invece di scartarla — un valore di classificazione imperfetto non deve far
perdere una spesa reale che l'utente ha effettivamente descritto.

**Non verificabile qui**: nessun runtime Deno disponibile in questa sessione (il download
dell'installer è bloccato dal proxy di rete, diversamente dalle slice precedenti dove `deno
check`/`deno lint`/`deno fmt --check` erano stati eseguibili) — le modifiche alla Edge Function
sono state rilette manualmente per correttezza sintattica e di tipo, non verificate con il
compilatore TypeScript.

### Mobile — interop col browser

`apps/mobile/lib/features/notifications/`: `PushNotificationService` (interfaccia) con due
implementazioni scelte a compile time tramite import condizionale su `dart.library.js_interop`
(`push_notification_service_web.dart` per il target web, con `dart:js_interop` + `package:web`;
`push_notification_service_stub.dart` no-op altrove). La conversione delle chiavi Web Push
(base64url senza padding, sia per la chiave pubblica VAPID sia per le chiavi restituite dal
browser) è isolata in `base64_url_codec.dart` — funzioni pure, **senza** dipendenza da
`dart:js_interop`, testate con `flutter test` (incluso un test con la chiave pubblica VAPID reale
generata per questa slice: 65 byte, prefisso `0x04` del punto EC non compresso).

`apps/mobile/web/push-worker.js`: service worker dedicato agli eventi `push`/`notificationclick`,
file sorgente distinto da `flutter_service_worker.js` (generato da Flutter per il caching, sempre
sovrascritto ad ogni build) — registrato in aggiunta da `push_notification_service_web.dart`, non
da `index.html`.

**Verificato**: `flutter analyze` (risoluzione reale delle API di `package:web` tramite
l'analyzer) e un vero `flutter build web` con dart2js (compila per il target web, non solo
un'analisi VM) — entrambi puliti, confermano che l'interop è sintatticamente e tipologicamente
corretto contro la versione reale del pacchetto. **Non verificabile qui**: il comportamento a
runtime in un browser reale (richiesta del permesso, sottoscrizione effettiva, notifica
recapitata) — nessun browser disponibile in questo ambiente. Verifica manuale richiesta all'utente
(vedi `apps/mobile/README.md`, "Limiti noti").

## Fasi successive

Memory, Agent, Calendar Event, Timeline Event sono già modellate in `packages/domain` ma non
hanno ancora una migrazione: arriveranno con le rispettive feature (`docs/product/26-execution-blueprint.md`).

Note tecniche aperte dal Domain Model, da risolvere prima di quelle migrazioni:

- `workspace_agents` come tabella di giunzione per la relazione many-to-many Agent↔Workspace.
- Vincolo di coerenza tra `Memory.level` e l'owner valorizzato (già applicato lato dominio in
  `packages/domain/lib/src/entities/memory.dart` con un `assert`; da replicare come `check`
  constraint quando la tabella verrà creata).
- Pattern polimorfico `entity_type` + `entity_id` per `Timeline Event`.
