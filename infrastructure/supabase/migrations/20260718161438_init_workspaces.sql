-- Fase 1 — Foundation: schema per il Workspace (docs/product/12-domain-model.md, entità
-- Workspace). L'isolamento tra utenti è applicato con Row Level Security, non solo lato
-- applicazione (Architectural Principles, Principio 9 — Sicurezza).

create extension if not exists pgcrypto;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  description text,
  icon text not null default 'folder',
  category text,
  status text not null default 'active' check (status in ('active', 'archived')),
  color text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint workspaces_name_not_blank check (btrim(name) <> '')
);

comment on table public.workspaces is
  'Domain Model, entita'' Workspace (docs/product/12-domain-model.md). ID come UUID v4 '
  '(gen_random_uuid): lo standard "UUID v7" richiesto dall''AI Engineering Playbook va '
  'introdotto con un generatore dedicato quando disponibile, senza cambiare il tipo di colonna.';

create index if not exists workspaces_owner_id_idx on public.workspaces (owner_id);
create index if not exists workspaces_owner_created_idx on public.workspaces (owner_id, created_at desc);

-- Realtime (Software Architecture, "Sincronizzazione"): la UI osserva i Workspace in streaming.
alter publication supabase_realtime add table public.workspaces;

alter table public.workspaces enable row level security;

-- Fase 1: Workspace personali, un solo proprietario. I Workspace condivisi (Fase 6 —
-- Collaboration) richiederanno una tabella di membership e policy aggiuntive, non una
-- riscrittura di queste (Architectural Principles, Principio 10 — Evoluzione).
create policy "workspaces_select_own"
  on public.workspaces for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "workspaces_insert_own"
  on public.workspaces for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "workspaces_update_own"
  on public.workspaces for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "workspaces_delete_own"
  on public.workspaces for delete
  to authenticated
  using (auth.uid() = owner_id);
