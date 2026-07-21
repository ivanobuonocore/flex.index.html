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

**Fix (bug segnalato dall'utente: "ci sono più categorie di appuntamenti")**: questa migrazione
non era ancora stata applicata a un progetto Supabase reale — nel frattempo il bootstrap lato app
ha potuto inserire più righe con la stessa categoria a ogni ricarica, senza che nulla lo
impedisse (l'unico argine reale era proprio questo indice, mai attivo). Aggiunta all'inizio della
stessa migrazione una query che disattiva (soft delete) le sezioni fisse duplicate, mantenendo la
più vecchia per ciascuna `(owner_id, categoria)`, prima di creare l'indice — così chi non ha
ancora eseguito `db push` non troverà l'indice fallire per violazione dei dati esistenti.
Idempotente (eseguita di nuovo dopo che l'indice esiste, non trova più righe da disattivare).
Fix speculare lato app: `workspacesProvider` (`apps/mobile`) filtra ora le sezioni fisse
duplicate allo stesso modo, così l'interfaccia è corretta anche prima che la migrazione venga
applicata.

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

## Fase 3 (slice 8) — Bilancio condiviso

Richiesta esplicita dell'utente: condividere il Bilancio con un'altra persona (account separato),
con la possibilità che ciascuno mantenga anche un proprio Bilancio personale. Un Bilancio condiviso
è semplicemente un Workspace "libero" (non una sezione fissa, non lo stesso Workspace personale) a
cui un secondo utente viene ammesso tramite invito — non introduce Workspace condivisi in generale.

### `public.workspace_members` / `public.workspace_invites`

| Tabella              | Colonne                                                                    |
|-----------------------|-----------------------------------------------------------------------------|
| `workspace_members`   | `workspace_id`, `user_id`, `joined_at`, univoco su `(workspace_id, user_id)` |
| `workspace_invites`   | `workspace_id`, `code` (univoco, 8 esadecimali maiuscoli), `created_by`, `expires_at` (default +7 giorni), `used_at`, `used_by` |

**Scope volutamente ridotto (risposta esplicita dell'utente, "Solo il Bilancio")**: le policy RLS
aggiuntive di questa migrazione toccano solo `workspaces` (select) e `transactions` (select/insert/
update/delete). Le policy di `notes`/`tasks`/`documents` non vengono toccate: restano visibili solo
al proprietario, anche per un Workspace di cui qualcun altro è membro.

**Additivo, non una riscrittura**: le nuove policy (`workspaces_select_member`,
`transactions_*_member`) sono policy permissive separate — Postgres le combina in OR con quelle
esistenti (`workspaces_select_own`, `transactions_*_own_workspace`), mai toccate. Esattamente come
anticipato dal commento nella prima migrazione Fase 1.

### `public.redeem_workspace_invite(code text) returns uuid`

SECURITY DEFINER (non invoker): un invitato non ha — e non deve avere — una policy `select` su
`workspace_invites` per trovare la riga tramite il codice; questa funzione è l'unico modo per
farlo, con validazione esplicita dentro la funzione (non un passthrough di privilegi). Verifica:
codice esistente, non scaduto, non già usato, non creato dallo stesso utente che lo sta redimendo.
Ritorna solo l'id del Workspace: il client legge poi il Workspace completo tramite la normale
`watchWorkspaces()`, ora visibile grazie a `workspaces_select_member`.

**Due bug reali trovati e corretti verificando su Postgres locale con due utenti simulati**:

1. **Ricorsione infinita tra le RLS di `workspaces` e `workspace_members`**: `workspaces_select_member`
   interroga `workspace_members`; la prima versione delle policy di `workspace_members` interrogava a
   sua volta `workspaces` per verificare la proprietà — Postgres valutava le due RLS a catena
   all'infinito (`infinite recursion detected in policy for relation workspaces`). Corretto con una
   funzione `is_workspace_owner(workspace_id)` SECURITY DEFINER: gira con i privilegi di chi l'ha
   creata (proprietaria anche di `workspaces`), bypassando la RLS su quella tabella e rompendo il
   ciclo.
2. **Colonna ambigua in `redeem_workspace_invite`**: la funzione dichiarava `returns table
   (workspace_id uuid, workspace_name text)` — Postgres espone i nomi delle colonne di ritorno come
   variabili PL/pgSQL implicite nel corpo della funzione, in conflitto con la colonna omonima usata in
   `on conflict (workspace_id, user_id)` (`column reference "workspace_id" is ambiguous`). Risolto
   semplificando la funzione a `returns uuid` (solo l'id, il nome si legge da `watchWorkspaces()`).

**Verificato manualmente su Postgres locale, due utenti simulati (A proprietario, B invitato)**:
isolamento completo prima dell'invito (0 righe visibili a B su workspace/transazioni/note);
`redeem_workspace_invite` rifiuta un codice scaduto, un codice già usato, un codice inesistente, e
il proprietario che prova a unirsi al proprio invito; dopo il redeem B vede il Workspace e le
transazioni (comprese quelle inserite da A prima della condivisione — non c'è "storico" da
proteggere in un Workspace appena creato per essere condiviso) e può inserirne di nuove, ma
l'inserimento di una nota da parte di B viene bloccato dalla RLS esistente (invariata); dopo che A
rimuove B dai membri, B perde di nuovo ogni accesso.

**Non verificabile qui**: nessuna chiamata reale a `redeem_workspace_invite` tramite Supabase RPC
(richiede un progetto remoto) — verificato lo stesso comportamento SQL su Postgres locale, non il
trasporto RPC in sé.

## Fase 3 (slice 9) — Promemoria via Chat

Richiesta esplicita dell'utente: notifiche push vere per i promemoria (non un semplice elenco in
app) — riusa l'infrastruttura Web Push già costruita e provata nella slice `push_subscriptions`/
`send-test-push`.

### `public.calendar_events`

Stesso pattern RLS a join di `notes`/`tasks` (`EXISTS` su `workspaces.owner_id = auth.uid()`).

| Colonna                    | Note                                                                |
|----------------------------|----------------------------------------------------------------------|
| `workspace_id`             | FK cascade, obbligatorio — sempre la sezione Appuntamenti se creato dalla Chat |
| `title`                    | non vuoto (constraint)                                                |
| `starts_at`                | data/ora del promemoria                                              |
| `duration_minutes`         | default 30                                                            |
| `reminder_minutes_before`  | facoltativo — anticipo dell'avviso rispetto a `starts_at`             |
| `source_task_id`/`source_chat_id` | facoltativi — origine se derivato da una Task o da un messaggio di Chat |
| `notified_at`              | valorizzato da `send-due-reminders` non appena inviata la notifica — evita un secondo invio |

**A differenza di `transactions`, nessuno stato "pending/confirmed"**: un promemoria non è un dato
finanziario da poter contare per errore, ed è banalmente reversibile (si elimina con uno swipe) —
inserito direttamente, sia manualmente sia dall'Edge Function `ai-chat`.

**Estrazione lato Edge Function `ai-chat`**: nuovo tool Anthropic `create_reminder` (schema JSON:
`title`, `starts_at` ISO 8601, `reminder_minutes_before` facoltativo), attivo solo quando la Chat
riceve un `remindersWorkspaceId` valido (parametro separato da `workspaceId`, sempre la sezione
Bilancio — un promemoria non appartiene mai al Workspace delle transazioni). Può comparire insieme
a `extract_transactions` nello stesso turno (un messaggio può descrivere sia una spesa sia un
promemoria). Validazione difensiva (`sanitizeReminder`) analoga a `sanitizeTransaction`: una data
non parsabile scarta il suggerimento invece di fallire l'intero turno.

**Verificato manualmente su Postgres locale**: isolamento cross-utente su `calendar_events`
(select/insert bloccati per un Workspace non proprio).

**Non verificabile in questa sessione**: nessun runtime Deno disponibile (come per l'ultima
modifica a `ai-chat` in Fase 3 slice 7C) — `ai-chat/index.ts` e la nuova function
`send-due-reminders` sono state rilette manualmente per correttezza sintattica e di tipo, non
verificate con il compilatore TypeScript. Nessuna chiamata reale al provider Anthropic.

### Edge Function `send-due-reminders`

**L'unica function di questo progetto che usa la service role**, non il JWT di un utente —
giustificato esplicitamente: è invocata da un cron job Postgres (`pg_cron`, ogni minuto), non da
una richiesta di un utente autenticato, quindi non esiste un JWT da inoltrare. Deve poter leggere
`calendar_events` di **tutti** gli utenti (per trovare i promemoria scaduti) e le rispettive
`push_subscriptions` per inviare la notifica — le RLS di quelle tabelle restano intatte per ogni
altro accesso, qui vengono bypassate by design.

Legge i promemoria con `notified_at is null` entro una finestra di lettura di 24 ore (limite
prudenziale sulla query, non sul momento effettivo dell'invio), poi filtra riga per riga il
momento di invio reale (`starts_at` meno l'eventuale `reminder_minutes_before`) contro `now()`.
Marca `notified_at` su ogni promemoria elaborato indipendentemente dal numero di iscrizioni push
raggiunte con successo (anche zero): un avviso a tempo non deve essere ritentato indefinitamente
né consegnato in ritardo una volta risolto un problema di iscrizione.

**Attivazione del cron (da eseguire manualmente, SQL commentato in fondo alla migrazione
`20260722090000_calendar_events.sql`)**: richiede le estensioni `pg_cron`/`pg_net` abilitate
(Database → Extensions nel pannello Supabase, non attive di default) e la Service Role Key del
progetto come Bearer token della chiamata HTTP pianificata — `SUPABASE_SERVICE_ROLE_KEY` è invece
già disponibile automaticamente **dentro** ogni Edge Function, non va configurato come secret.

**Non verificabile in questa sessione**: nessun `pg_cron`/`pg_net` disponibili su Postgres locale
(estensioni specifiche di Supabase), nessuna chiamata reale alla function. Verificato solo
staticamente (rilettura manuale, nessun Deno disponibile).

## Fase 3 (slice 10) — Q&A su dati reali in Chat

Richiesta esplicita dell'utente: la Chat deve saper rispondere a "qualsiasi domanda che riguardi
le informazioni al suo interno" (es. "quanto ho speso questo mese", "ho appuntamenti il mese
prossimo"), non solo registrare transazioni/promemoria. Nessuna nuova tabella: legge solo
`transactions`/`calendar_events` già esistenti.

**Due nuovi tool Anthropic in `ai-chat`, sempre attivi** (a differenza di
`extract_transactions`/`create_reminder`, non dipendono da un Workspace attivo — funzionano in
qualunque Chat, perché leggono sotto RLS solo i dati del chiamante):

- `query_balance_summary(period_start, period_end)` — somma entrate/uscite confermate nel
  periodo, con dettaglio per categoria di spesa. **Esclude sempre i Bilanci condivisi**
  (`SHARED_BALANCE_CATEGORY = 'bilancio_condiviso'`, duplicato da
  `packages/domain/lib/src/shared_balance_category.dart` — stesso principio già applicato a
  `TRANSACTION_CATEGORIES`, nessuna condivisione di tipi tra Dart e TypeScript in questo
  progetto): stessa esclusione già applicata lato client in `BalanceOverviewScreen`, replicata
  qui perché questa function non ha altro modo di saperlo.
- `query_reminders(period_start, period_end)` — elenca i promemoria non cancellati nel periodo.
  Nessun filtro aggiuntivo oltre a RLS: `calendar_events` non ha un concetto di condivisione
  (owner-only).

**Perché un secondo giro con Anthropic**: quando il modello chiama uno di questi due strumenti,
non può scrivere la risposta in prosa nello stesso turno in cui chiede il dato — deve prima
ricevere il risultato reale. `ai-chat` esegue quindi la query sotto RLS (stesso client con il JWT
del chiamante usato per tutta la function, nessun privilegio aggiuntivo) e fa **una sola** seconda
chiamata ad Anthropic con il risultato come `tool_result`, senza il parametro `tools` — il modello
non può quindi chiedere un'altra chiamata, limitando esplicitamente il costo/la latenza aggiuntivi
a un solo giro extra, e solo nei turni in cui serve davvero. Se lo stesso turno contiene anche un
`tool_use` di `extract_transactions`/`create_reminder` (un messaggio può mescolare una domanda e
una nuova spesa), riceve comunque un `tool_result` "di cortesia" — l'API Anthropic richiede una
risposta per ogni `tool_use` del turno precedente — l'inserimento reale in `transactions`/
`calendar_events` resta invariato, indipendente da questo secondo giro.

**Verificato in questa sessione**: `tsc --strict --noUnusedLocals --noUnusedParameters` (compilatore
TypeScript reale, non solo rilettura manuale come nelle slice precedenti — Deno stesso resta
comunque non disponibile in questo sandbox) su `ai-chat/index.ts` con shim locali per gli import
`npm:` e i globali `Deno.*`: nessun errore di sintassi o di tipo.

**Non verificabile in questa sessione**: nessuna chiamata reale al provider Anthropic né al
progetto Supabase reale dell'utente — il comportamento end-to-end (il modello sceglie lo strumento
giusto, il secondo giro produce una risposta pertinente) va verificato in produzione.

**Aggiornato**: `QUERY_TOOL_INSTRUCTIONS` richiede ora esplicitamente che la risposta dichiari un
totale in una frase diretta (es. "Hai speso 340,00€ questo mese") prima di un eventuale elenco di
dettaglio — richiesta esplicita dell'utente: "non soltanto riportarmi le transazioni... ma farmi
un totale". Nessun cambiamento di schema o di logica di query, solo del testo dell'istruzione.

## Fase 3 (slice 11) — Calendario mensile per Appuntamenti (solo client)

Richiesta esplicita dell'utente: "un calendario fatto a quadratini (giorni) dove su ogni giorno
viene riportato l'appuntamento". Nessuna migrazione, nessun cambiamento lato Edge Function: legge
lo stesso stream `calendar_events` già esistente (`watchEvents`), aggregando gli eventi per giorno
solo lato client per disegnare la griglia mensile in `ReminderListScreen`. Un promemoria creato
dalla Chat (tool `create_reminder`, invariato) compare quindi automaticamente nel calendario non
appena la riga viene inserita — nessun collegamento nuovo da costruire.

Nessuna nuova dipendenza pub (es. `table_calendar`): pub.dev non è nella lista degli host
raggiungibili dal proxy di questo sandbox (solo npm/jsr/pypi/crates/proxy.golang.org), quindi
un'eventuale nuova dipendenza non sarebbe verificabile qui con `flutter pub get`/`flutter analyze`/
`flutter test` — la griglia è stata scritta a mano con `GridView.count`, verificabile con gli
stessi strumenti già usati in questa sessione.

**Aggiornato**: il banner di stato notifiche in Appuntamenti (`_NotificationStatusBanner`,
richiesta esplicita dell'utente) non introduce alcuno schema nuovo — riusa `push_subscriptions`
(già esistente, Fase 3 "Promemoria via Chat") tramite gli stessi provider Riverpod già usati in
Profilo. Allo stesso modo il dettaglio "per categoria" delle pillole Entrate/Uscite nel Bilancio è
puro client-side: aggrega `transactions.category` già letta da `watchTransactions`, nessuna nuova
colonna o funzione SQL.

## Fase 3 (slice 12) — Ricerca estesa a Transazioni/Promemoria, Liste via Chat, tema, tag Note

Quattro migliorie richieste esplicitamente dall'utente in un unico giro, verificate insieme:

- **Ricerca Universale** (`20260722150000_search_transactions_and_reminders.sql`): due nuovi
  indici GIN (`transactions.description`, `calendar_events.title`) e `search_workspace_content`
  ridefinita con due `union all` aggiuntivi. Solo le transazioni **confermate** compaiono (le
  pending sono suggerimenti non ancora decisi dall'utente, AI Constitution Principio 1); i
  promemoria non richiedono lo stesso filtro (non hanno uno stato pending/confirmed). Verificato
  su Postgres locale con lo stesso schema fittizio (`auth`/`storage`/`supabase_realtime` stub) già
  usato per le slice precedenti: RLS isolation confermata (un secondo utente non vede i risultati
  del primo), transazione pending correttamente esclusa dal risultato.
- **Liste/checklist via Chat** (Slice C del piano originale, mai realizzata finora): nuovo tool
  `manage_tasks` in `ai-chat/index.ts`, stesso pattern di `create_reminder` — un `Task` per
  elemento (`generated_by_ai: true`, `chat_id` valorizzato), nessuna migrazione (le colonne
  esistevano già dalla slice Note/Task originale). Richiede un terzo id di sezione,
  `tasksWorkspaceId` (Attività), aggiunto end-to-end accanto a `workspaceId`/
  `remindersWorkspaceId` già esistenti (client → `SupabaseMessageRepository.sendMessage` →
  `ai-chat` → `buildSystemPrompt`).
- **Tema chiaro/scuro**: nessuna tabella nuova — la preferenza (`AppThemeMode` in
  `packages/domain`) è salvata nei metadata di Supabase Auth (`auth.updateUser({data: {theme_mode:
  ...}})`), stesso meccanismo già usato per `name` alla registrazione. Si riflette in
  `watchCurrentUser` tramite l'evento `userUpdated` di `onAuthStateChange`, nessuno stato locale
  duplicato.
- **Tag sulle Note**: `notes.tags` esisteva già dalla migrazione originale (mai esposto in UI) —
  nessuna modifica di schema, solo `NoteFormController.create` che ora inoltra `tags` (già
  accettato da `NoteRepository.createNote`) e una nuova striscia di filtro rapido lato client.

## Fase 3 (slice 13) — Conferma/Scarta inline in Chat

`20260722160000_message_pending_transaction_ids.sql`: `messages.pending_transaction_ids
text[]`, stessa convenzione di `attachment_ids`/`source_references` (non un vero array di FK,
nessun vincolo referenziale). `ai-chat/index.ts` cattura gli id restituiti dall'insert in
`transactions` (`.select("id")`) e li salva sul messaggio dell'assistente appena creato — la Chat
può così mostrare Conferma/Scarta subito sotto la risposta (richiesta esplicita dell'utente:
"azioni rapide sulle transazioni pending direttamente in chat"), riusando lo stesso
`transactionFormControllerProvider` già usato dal Bilancio. La colonna non viene aggiornata quando
una transazione viene confermata/scartata altrove: il client filtra sempre per
`status == pending` al momento della lettura (`transactionsProvider(null)`), quindi un id ormai
deciso smette semplicemente di comparire, senza dover riscrivere il messaggio. Verificato su
Postgres locale (stesso schema fittizio delle slice precedenti): insert e lettura della colonna
confermati.

## Fase 3 (slice 14) — Promemoria ricorrenti

`20260722170000_calendar_events_recurrence.sql`: `calendar_events.recurrence_group_id uuid`
(nullable, indice parziale `where recurrence_group_id is not null`). Nessuna logica RRULE/cron:
`create_reminder` guadagna un campo `recurrence` (`none`/`daily`/`weekly`/`monthly`, richiesta
esplicita dell'utente — "ogni lunedì", "ogni mese") e `ai-chat/index.ts` **espande** la
ricorrenza in più righe indipendenti al momento della creazione (`expandOccurrences`), ciascuna
col proprio `starts_at` e un `recurrence_group_id` condiviso (`crypto.randomUUID()`) —
`send-due-reminders` (già configurata, non toccata da questa slice) continua a leggere
`calendar_events` come eventi indipendenti, esattamente come faceva prima. Numero di occorrenze
fisso per frequenza (14 giorni/14 settimane/12 mesi), non deciso dal modello: evita inserimenti
incontrollati.

Bug trovato e corretto durante lo sviluppo (verificato con uno script Node standalone, dato che
Deno non è disponibile in questo sandbox): `Date.setUTCMonth` da solo trabocca sui mesi più corti
— il 31 gennaio + 1 mese diventava il 3 marzo invece del 28 febbraio. La correzione passa sempre
dal giorno 1 del mese di destinazione, poi sceglie `min(giorno originale, giorni nel mese di
destinazione)`.

`recurrenceGroupId` (`CalendarEvent` in `packages/domain`) è solo informativo in questa slice:
mostra un'icona "ricorrente" nell'elenco Appuntamenti, ma eliminare un'occorrenza elimina solo
quella riga — non l'intera serie (tenuto fuori scope per non appesantire questo giro). Verificato
su Postgres locale: insert di più righe con lo stesso `recurrence_group_id` e lettura confermati.

## Fase 3 (slice 15) — Memoria: prima slice minima

Prima persistenza reale dell'entità `Memory` (Domain Model — mai costruita finora, uno dei
pilastri di prodotto citati in CLAUDE.md). Scope volutamente ridotto (richiesta esplicita
dell'utente): solo il livello **Globale** (legato all'utente, non a un Workspace o una Chat).

`20260722180000_memories.sql`: tabella `public.memories` (id, content, level, origin, user_id/
workspace_id/chat_id — tutte nullable, con un check `memories_owner_matches_level` che rispecchia
l'`assert` del costruttore Dart `Memory`), `memories_content_not_blank`, RLS con tre policy
(`select`/`insert`/`delete`) tutte ristrette a `level = 'global' and user_id = auth.uid()` —
Workspace e Conversazione restano colonne nullable senza policy, arriveranno con le rispettive
feature senza un'altra migrazione. Verificato su Postgres locale: un utente non vede né può
cancellare la memoria di un altro, un insert cross-user o a livello workspace/conversation viene
respinto dalla RLS, i check constraint su contenuto vuoto e owner mancante funzionano.

`ai-chat/index.ts`: nuovo tool `remember_fact`, **sempre disponibile** (come
`query_balance_summary`/`query_reminders`, non condizionato a un Workspace — la Memoria è legata
all'utente). Nessun meccanismo pending/confirmed: come i promemoria/le liste, è reversibile con un
tocco (si cancella dalla schermata Memoria), non un dato finanziario da dover contare con cautela.
Le memorie esistenti vengono anche **iniettate nel system prompt** di ogni turno
(`buildSystemPrompt`, sezione "Cose da ricordare su questo utente", fino a 20 più recenti) —
altrimenti la feature sarebbe di sola scrittura: l'AI deve poterle effettivamente usare nelle
risposte future, non solo salvarle.

Mobile: `features/memory/` (data/application/presentation) con lo stesso pattern di
`features/reminder/` — `SupabaseMemoryRepository` (solo `watchGlobalMemories`/`deleteMemory`,
nessuna creazione manuale: le memorie nascono solo dall'AI), `MemoryListScreen` raggiungibile da
Profilo → "Memoria" (`/profile/memories`), nessun pulsante "+" per lo stesso motivo.

## Fasi successive

Agent, Timeline Event sono già modellate in `packages/domain` ma non hanno ancora una migrazione:
arriveranno con le rispettive feature (`docs/product/26-execution-blueprint.md`). Memory ha ora
una migrazione, ma solo per il livello Globale (vedi slice 15 sopra) — Workspace e Conversazione
restano da implementare.

Note tecniche aperte dal Domain Model, da risolvere prima di quelle migrazioni:

- `workspace_agents` come tabella di giunzione per la relazione many-to-many Agent↔Workspace.
- Vincolo di coerenza tra `Memory.level` e l'owner valorizzato (già applicato lato dominio in
  `packages/domain/lib/src/entities/memory.dart` con un `assert`; da replicare come `check`
  constraint quando la tabella verrà creata).
- Pattern polimorfico `entity_type` + `entity_id` per `Timeline Event`.
