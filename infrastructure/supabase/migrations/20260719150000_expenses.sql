-- Entità Expense (aggiunta oltre allo scaffold originale — vedi
-- docs/database/README.md e docs/product/12-domain-model.md). Stesso pattern RLS di
-- notes/tasks/documents: nessuna colonna owner_id diretta, appartenenza verificata
-- via EXISTS sul Workspace referenziato.

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  -- Nullable: valorizzato solo per le spese estratte dalla Chat dall'AI Engine.
  chat_id uuid references public.chats (id) on delete set null,
  description text not null,
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'EUR',
  occurred_at timestamptz not null default now(),
  status text not null default 'confirmed' check (status in ('pending', 'confirmed')),
  created_by_ai boolean not null default false,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint expenses_description_not_blank check (btrim(description) <> '')
);

comment on table public.expenses is
  'Domain Model, entita'' Expense (aggiunta oltre allo scaffold originale). Le spese create '
  'dall''AI Engine (ai-chat) nascono con status=''pending'' e created_by_ai=true; diventano '
  '''confirmed'' solo su conferma esplicita dell''utente (AI Constitution, Principio 1) e solo '
  'allora contano nei totali della schermata Spese.';

create index if not exists expenses_workspace_id_idx on public.expenses (workspace_id);
create index if not exists expenses_workspace_occurred_idx
  on public.expenses (workspace_id, occurred_at desc);

alter publication supabase_realtime add table public.expenses;

alter table public.expenses enable row level security;

create policy "expenses_select_own_workspace"
  on public.expenses for select
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = expenses.workspace_id and w.owner_id = auth.uid()
  ));

create policy "expenses_insert_own_workspace"
  on public.expenses for insert
  to authenticated
  with check (exists (
    select 1 from public.workspaces w
    where w.id = expenses.workspace_id and w.owner_id = auth.uid()
  ));

create policy "expenses_update_own_workspace"
  on public.expenses for update
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = expenses.workspace_id and w.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspaces w
    where w.id = expenses.workspace_id and w.owner_id = auth.uid()
  ));

create policy "expenses_delete_own_workspace"
  on public.expenses for delete
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = expenses.workspace_id and w.owner_id = auth.uid()
  ));
