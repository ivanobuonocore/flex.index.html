-- Spese/entrate ricorrenti automatiche (Domain Model, entità
-- RecurringTransactionTemplate — richiesta esplicita dell'utente: "spese
-- ricorrenti automatiche", stesso motore già costruito per i Promemoria
-- ricorrenti, applicato alle Transazioni). Stesso pattern RLS di
-- transactions/notes/tasks: nessuna colonna owner_id diretta, appartenenza
-- verificata via EXISTS sul Workspace referenziato.
--
-- A differenza dei Promemoria ricorrenti (tutte le occorrenze pre-generate
-- subito), qui si genera UNA Transaction pending alla volta, solo quando
-- dovuta (Edge Function `create-due-recurring-transactions`, invocata da un
-- cron job Postgres) — un elenco "in attesa di conferma" con 12 mesi di
-- spese future già presenti confonderebbe la sezione, oltre a non avere
-- senso finanziariamente (non si "deve" ancora nulla per un mese futuro).
create table if not exists public.recurring_transaction_templates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  description text not null,
  amount_cents integer not null check (amount_cents > 0),
  category text not null check (category in (
    'alimentari', 'trasporti', 'casa', 'bollette', 'salute', 'svago',
    'shopping', 'istruzione', 'stipendio', 'altro'
  )),
  frequency text not null check (frequency in ('weekly', 'monthly')),
  next_occurrence_at date not null,
  -- Giorno del mese "vero" della ricorrenza (1-31), fissato alla creazione e mai
  -- ricalcolato dalla data corrente: senza questo, un mese corto (es. Feb 28)
  -- farebbe "scivolare" la scadenza al 28 per sempre invece di tornare al 31 nei
  -- mesi più lunghi — stesso bug già trovato e corretto per i Promemoria
  -- ricorrenti (expandOccurrences in ai-chat/index.ts). Non usata per frequency
  -- = 'weekly' (sempre 1-7, irrilevante).
  anchor_day integer not null check (anchor_day between 1 and 31),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint recurring_transaction_templates_description_not_blank
    check (btrim(description) <> '')
);

comment on table public.recurring_transaction_templates is
  'Domain Model, entita'' RecurringTransactionTemplate (docs/product/12-domain-model.md). '
  'Scritta solo dall''AI Engine (tool create_recurring_transaction).';

create index if not exists recurring_transaction_templates_workspace_id_idx
  on public.recurring_transaction_templates (workspace_id);
create index if not exists recurring_transaction_templates_due_idx
  on public.recurring_transaction_templates (next_occurrence_at)
  where deleted_at is null;

alter table public.recurring_transaction_templates enable row level security;

create policy "recurring_transaction_templates_select_own_workspace"
  on public.recurring_transaction_templates for select
  using (exists (
    select 1 from public.workspaces w
    where w.id = recurring_transaction_templates.workspace_id and w.owner_id = auth.uid()
  ));

create policy "recurring_transaction_templates_insert_own_workspace"
  on public.recurring_transaction_templates for insert
  with check (exists (
    select 1 from public.workspaces w
    where w.id = recurring_transaction_templates.workspace_id and w.owner_id = auth.uid()
  ));

-- Soft delete (Domain Model, "Principi del modello") via `deleted_at`: serve una policy
-- UPDATE, non DELETE — dimenticarla lascerebbe l'update silenziosamente a 0 righe sotto
-- RLS (nessun errore, nessun effetto), stesso pattern di calendar_events.
create policy "recurring_transaction_templates_update_own_workspace"
  on public.recurring_transaction_templates for update
  using (exists (
    select 1 from public.workspaces w
    where w.id = recurring_transaction_templates.workspace_id and w.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspaces w
    where w.id = recurring_transaction_templates.workspace_id and w.owner_id = auth.uid()
  ));

grant select, insert, update on public.recurring_transaction_templates to authenticated;

-- Edge Function `create-due-recurring-transactions` (infrastructure/supabase/functions):
-- invocata da un cron job Postgres, non da una richiesta HTTP di un utente autenticato —
-- non esiste un JWT da inoltrare. Deve poter leggere/scrivere i modelli ricorrenti E le
-- transazioni di TUTTI gli utenti (per generare quelle dovute): la service role bypassa
-- le RLS sopra by design, stesso principio già applicato a `send-due-reminders`.
--
-- pg_cron/pg_net non sono abilitate di default: vanno attivate manualmente (Database →
-- Extensions, nel pannello Supabase) prima di eseguire quanto segue — se già attivate per
-- send-due-reminders, questo passaggio è già stato fatto. Il secret <SERVICE_ROLE_KEY> va
-- sostituito con la Service Role Key del progetto (Project Settings → API).
--
-- select cron.schedule(
--   'create-due-recurring-transactions',
--   '0 3 * * *', -- una volta al giorno, alle 03:00 UTC
--   $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/create-due-recurring-transactions',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'Authorization', 'Bearer <SERVICE_ROLE_KEY>'
--     ),
--     body := '{}'::jsonb
--   );
--   $$
-- );
