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

Le altre entità del Domain Model (Chat, Memory, Agent, ...) avranno le proprie migrazioni quando
le rispettive feature verranno implementate (Fase 2+, `docs/product/26-execution-blueprint.md`)
— lo schema non richiede di riscrivere quelle esistenti per crescere (Engineering Constitution,
Articolo 8).

## Nota su Realtime

`workspaces`, `notes`, `tasks` e `documents` sono pubblicate su `supabase_realtime`: `apps/mobile`
osserva le tabelle in streaming invece di fare polling (Software Architecture,
"Sincronizzazione").

## Nota su Storage

Il bucket `documents` è privato: `apps/mobile` non usa mai un URL pubblico diretto, solo signed
URL a validità breve (`SupabaseDocumentRepository.getDownloadUrl`, 60 secondi). Le policy RLS su
`storage.objects` non sono verificabili end-to-end senza il servizio Storage completo di Supabase
(`supabase start` con Docker, o un progetto remoto) — non disponibili in questa sessione.
