# infrastructure/supabase

Configurazione e migrazioni del progetto Supabase (Postgres, Auth, Realtime — Software
Architecture, "Database").

## Setup locale

Richiede [Docker](https://www.docker.com/) e la [Supabase CLI](https://supabase.com/docs/guides/cli):

```
cd infrastructure/supabase
npx supabase start
npx supabase db reset   # applica tutte le migrazioni da zero
```

`supabase start` stampa `API URL` e `anon key` locali: usali per avviare l'app mobile
(vedi `apps/mobile/README.md`).

## Collegare un progetto Supabase remoto

```
npx supabase link --project-ref <ref-progetto>
npx supabase db push
```

## Migrazioni

- `migrations/20260718161438_init_workspaces.sql` — tabella `workspaces` (Domain Model,
  `docs/product/12-domain-model.md`) con Row Level Security: ogni utente vede e modifica solo i
  propri Workspace (Architectural Principles, Principio 9). Verificato manualmente contro un
  Postgres locale: isolamento in lettura, scrittura e aggiornamento confermato.
- `migrations/20260718235106_notes_and_tasks.sql` — tabelle `notes` e `tasks` (Fase 2, slice 1),
  RLS tramite `EXISTS` sul Workspace referenziato (nessuna colonna `owner_id` diretta). Verificato
  manualmente: select/insert/update/delete cross-Workspace tutti bloccati (vedi
  `docs/database/README.md` per il dettaglio).
- `migrations/20260719064756_documents.sql` — tabella `documents` (stesso pattern RLS di
  notes/tasks) + bucket Storage privato `documents` + policy su `storage.objects`. Verificato
  manualmente: la tabella contro un Postgres locale come le precedenti; le policy Storage con uno
  schema `storage` fittizio (non è Supabase Storage reale) — ha comunque permesso di individuare e
  correggere un bug di ambiguità di colonna nella condizione RLS. Dettagli in
  `docs/database/README.md`.
- `migrations/20260719071418_universal_search.sql` — funzione `search_workspace_content`
  (Ricerca Universale, Fase 2 slice 3), `security invoker` esplicito: l'isolamento dipende
  dalle RLS delle 4 tabelle sottostanti, non da un filtro nella funzione. Verificato
  manualmente con due utenti — nessuna fuga di dati cross-Workspace. Verifica ha anche trovato
  un bug di qualità (non sicurezza) sulla tokenizzazione dei nomi file, corretto. Dettagli in
  `docs/database/README.md`.
- `migrations/20260719103109_chats_and_messages.sql` — tabelle `chats` (`owner_id` diretto, come
  `workspaces`: una Chat può esistere senza Workspace) e `messages` (RLS tramite `EXISTS` sulla
  Chat, come `notes`/`tasks` verso `workspaces`); trigger che aggiorna `chats.last_message_at`
  a ogni nuovo messaggio. Verificato manualmente: isolamento cross-utente su entrambe le tabelle,
  trigger funzionante. Dettagli in `docs/database/README.md`.
- `migrations/20260719150000_transactions.sql` — tabella `transactions` (aggiunta oltre allo
  scaffold originale, vedi `docs/database/README.md`), copre sia entrate sia uscite (`type`),
  stesso pattern RLS a join di `notes`/`tasks`. Le transazioni estratte dalla Chat dall'AI Engine
  nascono `pending` e contano nel saldo solo dopo conferma esplicita dell'utente (AI Constitution,
  Principio 1). Verificato manualmente: isolamento cross-utente, constraint su tipo/importo/
  descrizione, calcolo del saldo.

- `migrations/20260720120000_push_subscriptions.sql` — tabella `push_subscriptions` (Notifiche
  push vere, prima slice — vedi `docs/database/README.md`), livello account (`user_id` diretto,
  come `workspaces`/`chats`), letta dalla Edge Function `send-test-push` per l'invio. Verificato
  manualmente: isolamento cross-utente su tutte le operazioni, constraint su campi non vuoti e
  sull'unicità di `endpoint`.

- `migrations/20260721160000_workspace_sharing.sql` — `workspace_members`/`workspace_invites` +
  `redeem_workspace_invite` (Fase 3, "Bilancio condiviso"). Verificato manualmente su Postgres
  locale con due utenti simulati: isolamento completo prima dell'invito, redeem che rifiuta codici
  scaduti/usati/propri, accesso concesso dopo il redeem e revocato dopo la rimozione.
- `migrations/20260723150000_workspace_member_roles.sql` — `workspace_members.role`/
  `workspace_invites.role` (Fase 3, "Permessi granulari sui Workspace condivisi" — integrazione
  richiesta esplicitamente): un viewer legge tutto ma ogni scrittura su transazioni/note/attività
  è bloccata dalla RLS; solo il proprietario può cambiare il ruolo di un membro (un
  auto-tentativo di promozione viene bloccato); `redeem_workspace_invite` assegna il ruolo portato
  dall'invito. Verificato manualmente su Postgres locale con cinque utenti simulati (owner,
  editor, viewer, un redeem di invito viewer, un membro "legacy" senza `role` esplicito per
  confermare il default `editor` retrocompatibile) — dettagli in `docs/database/README.md`.
- `migrations/20260723160000_category_budgets_alert_state.sql` — `category_budgets.
  last_alert_threshold`/`last_alert_month` (Fase 3, "Notifica push su budget quasi superato" —
  integrazione richiesta esplicitamente): tracciano l'ultima soglia (80/100) già notificata nel mese,
  scritti solo dalla Edge Function `send-budget-alert`, mai dal client. Puramente additiva
  (`add column if not exists`), nessuna RLS nuova da verificare (le policy di `category_budgets`
  esistenti si applicano identiche alle due colonne in più).

Le altre entità del Domain Model (Memory, Agent, ...) avranno le proprie migrazioni quando le
rispettive feature verranno implementate (`docs/product/26-execution-blueprint.md`) — lo schema
non richiede di riscrivere quelle esistenti per crescere (Engineering Constitution, Articolo 8).

## AI Engine (`ai-chat`)

L'AI Engine è la Edge Function `functions/ai-chat` (Deno/TypeScript) — non un servizio separato
(Architectural Principles: "mai il frontend collegato direttamente a un provider LLM"; tutte le
chiamate AI passano da qui). Oltre a rispondere in chat, quando la Chat ha un Workspace la
function offre ad Anthropic uno strumento (`tool use`) `extract_transactions` per riconoscere
spese ed entrate descritte dall'utente e registrarle come "in attesa di conferma"
(`docs/database/README.md`, Fase 3 slice 2). Legge anche eventuali foto allegate all'ultimo
messaggio dell'utente e le invia ad Anthropic come immagini (Fase 3 slice 3) — vedi
`docs/database/README.md` per i limiti (max 3 foto, ~5MB ciascuna, formati non standard come
HEIC non garantiti).

Guadagna anche una modalità isolata (`extractReceiptDocumentId` nel body — Fase 3, "OCR sugli
scontrini allegati manualmente", integrazione richiesta esplicitamente): letta uno scontrino/
ricevuta già caricato con la stessa pipeline immagine di sopra, forza il tool `extract_transactions`
(`tool_choice`, non "auto") e ritorna solo `{ ok, result }` — nessuna riga `chats`/`messages`
coinvolta, nessuno storico di conversazione. Riusa la stessa `ANTHROPIC_API_KEY`, nessun segreto
nuovo; modello fisso (`RECEIPT_EXTRACTION_MODEL`, coerente con `kDefaultAiModel` lato mobile) dato
che non c'è una riga `chats` da cui leggere `ai_model`.

Richiede una chiave Anthropic, mai committata nel repository:

```
npx supabase secrets set ANTHROPIC_API_KEY=<la-tua-chiave>
```

Per il deploy della function (richiede `supabase link` verso un progetto remoto):

```
npx supabase functions deploy ai-chat
```

**Non verificato in questa sessione**: nessuna chiave Anthropic disponibile, quindi nessuna
chiamata reale né al provider né alla function stessa tramite il runtime Supabase Functions
(richiederebbe `supabase start` con Docker o un progetto remoto). Verificato invece il codice
TypeScript con `deno check`/`deno lint`/`deno fmt --check` — dettagli in
`docs/database/README.md`.

## Notifiche push (`send-test-push`)

Prima slice delle notifiche push vere (`docs/database/README.md`, Fase 3 slice 4) — non fa parte
dell'AI Engine, è infrastruttura di consegna isolata in una function a sé. Legge
`push_subscriptions` dell'utente che chiama e invia una notifica di prova tramite `npm:web-push`.
Richiede una coppia di chiavi VAPID, generabile senza account esterno (a differenza di Anthropic):

```
npx web-push generate-vapid-keys
npx supabase secrets set \
  VAPID_PUBLIC_KEY=<chiave-pubblica> \
  VAPID_PRIVATE_KEY=<chiave-privata> \
  VAPID_SUBJECT=mailto:<tua-email>
```

La chiave pubblica va anche passata al client mobile in fase di build (non è segreta — viene
comunque inviata al browser):

```
flutter build web --dart-define=VAPID_PUBLIC_KEY=<chiave-pubblica> ...
```

Deploy:

```
npx supabase functions deploy send-test-push
```

**Non verificato in questa sessione**: nessuna chiamata HTTP reale alla function (richiederebbe un
progetto Supabase remoto o Docker), né una notifica realmente recapitata a un browser — vedi
`docs/database/README.md` per il dettaglio di cosa è stato verificato staticamente.

## Notifica push su budget quasi superato (`send-budget-alert`)

Stessa infrastruttura di `send-test-push` (VAPID, `push_subscriptions`), ma invocata direttamente
dal client mobile subito dopo aver creato/confermato una spesa (`docs/database/README.md`, Fase 3,
integrazione richiesta esplicitamente), non da un pulsante di prova. Riceve `budgetId`/`category`/
`spentCents`/`limitCents`, calcola se l'80% o il 100% del budget è stato superato e, se sì, invia
una push solo se quella soglia non è già stata notificata questo mese (`category_budgets.
last_alert_threshold`/`last_alert_month`, migrazione `20260723160000_category_budgets_alert_state.
sql`). Stesse chiavi VAPID già configurate per `send-test-push` — nessun segreto nuovo da
impostare:

```
npx supabase functions deploy send-budget-alert
```

**Non verificato in questa sessione**: stessa limitazione di `send-test-push` (nessuna chiamata
HTTP reale né notifica recapitata a un browser) — verificato staticamente con `deno check`/`deno
lint`/`deno fmt --check`.

## Nota su Realtime

`workspaces`, `notes`, `tasks` e `documents` sono pubblicate su `supabase_realtime`: `apps/mobile`
osserva le tabelle in streaming invece di fare polling (Software Architecture,
"Sincronizzazione").

## Nota su Storage

Il bucket `documents` è privato: `apps/mobile` non usa mai un URL pubblico diretto, solo signed
URL a validità breve (`SupabaseDocumentRepository.getDownloadUrl`, 60 secondi). Le policy RLS su
`storage.objects` non sono verificabili end-to-end senza il servizio Storage completo di Supabase
(`supabase start` con Docker, o un progetto remoto) — non disponibili in questa sessione.
