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

Le altre entità del Domain Model (Chat, Document, Memory, Agent, ...) avranno le proprie
migrazioni quando le rispettive feature verranno implementate (Fase 2+,
`docs/product/26-execution-blueprint.md`) — lo schema non richiede di riscrivere quelle esistenti
per crescere (Engineering Constitution, Articolo 8).

## Nota su Realtime

`workspaces`, `notes` e `tasks` sono pubblicate su `supabase_realtime`: `apps/mobile` osserva le
tabelle in streaming invece di fare polling (Software Architecture, "Sincronizzazione").
