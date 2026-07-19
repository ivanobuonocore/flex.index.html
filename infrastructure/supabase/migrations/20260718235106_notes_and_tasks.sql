-- Fase 2 (slice 1): Note e Task (docs/product/12-domain-model.md). A differenza di
-- `workspaces` (proprietario diretto), qui l'isolamento tra utenti passa dal join con
-- `workspaces`: una riga appartiene a chi possiede il Workspace referenziato.

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  title text not null,
  content text not null default '',
  tags text[] not null default '{}',
  created_by_ai boolean not null default false,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint notes_title_not_blank check (btrim(title) <> '')
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'done')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  due_at timestamptz,
  assignee_id uuid references auth.users (id),
  generated_by_ai boolean not null default false,
  document_id uuid,
  chat_id uuid,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint tasks_title_not_blank check (btrim(title) <> '')
);

comment on table public.notes is 'Domain Model, entita'' Note (docs/product/12-domain-model.md).';
comment on table public.tasks is 'Domain Model, entita'' Task (docs/product/12-domain-model.md). '
  'assignee_id/document_id/chat_id restano senza FK verso tabelle non ancora esistenti '
  '(condivisione Workspace e Document sono Fase 5/6 e Fase 2 slice 2).';

create index if not exists notes_workspace_id_idx on public.notes (workspace_id);
create index if not exists notes_workspace_updated_idx on public.notes (workspace_id, updated_at desc);
create index if not exists tasks_workspace_id_idx on public.tasks (workspace_id);
create index if not exists tasks_workspace_created_idx on public.tasks (workspace_id, created_at desc);

alter publication supabase_realtime add table public.notes;
alter publication supabase_realtime add table public.tasks;

alter table public.notes enable row level security;
alter table public.tasks enable row level security;

-- L'appartenenza si verifica tramite il Workspace referenziato, non tramite una colonna
-- owner_id diretta su notes/tasks (Architectural Principles, Principio 3 — Workspace
-- come confine logico del sistema).
create policy "notes_select_own_workspace"
  on public.notes for select
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = notes.workspace_id and w.owner_id = auth.uid()
  ));

create policy "notes_insert_own_workspace"
  on public.notes for insert
  to authenticated
  with check (exists (
    select 1 from public.workspaces w
    where w.id = notes.workspace_id and w.owner_id = auth.uid()
  ));

create policy "notes_update_own_workspace"
  on public.notes for update
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = notes.workspace_id and w.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspaces w
    where w.id = notes.workspace_id and w.owner_id = auth.uid()
  ));

create policy "notes_delete_own_workspace"
  on public.notes for delete
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = notes.workspace_id and w.owner_id = auth.uid()
  ));

create policy "tasks_select_own_workspace"
  on public.tasks for select
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = tasks.workspace_id and w.owner_id = auth.uid()
  ));

create policy "tasks_insert_own_workspace"
  on public.tasks for insert
  to authenticated
  with check (exists (
    select 1 from public.workspaces w
    where w.id = tasks.workspace_id and w.owner_id = auth.uid()
  ));

create policy "tasks_update_own_workspace"
  on public.tasks for update
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = tasks.workspace_id and w.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspaces w
    where w.id = tasks.workspace_id and w.owner_id = auth.uid()
  ));

create policy "tasks_delete_own_workspace"
  on public.tasks for delete
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = tasks.workspace_id and w.owner_id = auth.uid()
  ));
