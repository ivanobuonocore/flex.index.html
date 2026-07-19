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
- `migrations/20260719150000_expenses.sql` — tabella `expenses` (aggiunta oltre allo scaffold
  originale, vedi `docs/database/README.md`), stesso pattern RLS a join di `notes`/`tasks`. Le
  spese estratte dalla Chat dall'AI Engine nascono `pending` e contano nei totali solo dopo
  conferma esplicita dell'utente (AI Constitution, Principio 1). Verificato manualmente:
  isolamento cross-utente, constraint su importo e descrizione.

Le altre entità del Domain Model (Memory, Agent, ...) avranno le proprie migrazioni quando le
rispettive feature verranno implementate (`docs/product/26-execution-blueprint.md`) — lo schema
non richiede di riscrivere quelle esistenti per crescere (Engineering Constitution, Articolo 8).

## AI Engine (`ai-chat`)

L'AI Engine è la Edge Function `functions/ai-chat` (Deno/TypeScript) — non un servizio separato
(Architectural Principles: "mai il frontend collegato direttamente a un provider LLM"; tutte le
chiamate AI passano da qui). Oltre a rispondere in chat, quando la Chat ha un Workspace la
function offre ad Anthropic uno strumento (`tool use`) `extract_expenses` per riconoscere spese
descritte dall'utente e registrarle come "in attesa di conferma" (`docs/database/README.md`,
Fase 3 slice 2). Richiede una chiave Anthropic, mai committata nel repository:

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

## Nota su Realtime

`workspaces`, `notes`, `tasks` e `documents` sono pubblicate su `supabase_realtime`: `apps/mobile`
osserva le tabelle in streaming invece di fare polling (Software Architecture,
"Sincronizzazione").

## Nota su Storage

Il bucket `documents` è privato: `apps/mobile` non usa mai un URL pubblico diretto, solo signed
URL a validità breve (`SupabaseDocumentRepository.getDownloadUrl`, 60 secondi). Le policy RLS su
`storage.objects` non sono verificabili end-to-end senza il servizio Storage completo di Supabase
(`supabase start` con Docker, o un progetto remoto) — non disponibili in questa sessione.
