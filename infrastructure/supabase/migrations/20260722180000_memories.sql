-- Memoria (Domain Model, entita' Memory — uno dei pilastri di prodotto citati in
-- CLAUDE.md, mai costruito finora). Prima slice minima (richiesta esplicita
-- dell'utente): solo il livello globale (legato all'utente, non a un Workspace o a una
-- Chat) — l'AI salva una nota quando l'utente dice esplicitamente "ricorda che...".
--
-- Lo schema modella già tutti e 3 i livelli (globale/workspace/conversazione, vedi
-- MemoryLevel in packages/domain) per non dover fare un'altra migrazione quando
-- arriveranno gli altri due, ma la RLS di questa slice espone solo l'accesso al
-- livello globale: workspace_id/chat_id restano colonne nullable senza policy.
create table if not exists public.memories (
  id uuid primary key default gen_random_uuid(),
  content text not null,
  level text not null check (level in ('global', 'workspace', 'conversation')),
  origin text not null check (origin in ('user', 'ai')),
  user_id uuid references auth.users (id) on delete cascade,
  workspace_id uuid references public.workspaces (id) on delete cascade,
  chat_id uuid references public.chats (id) on delete cascade,
  updated_at timestamptz not null default now(),
  constraint memories_content_not_blank check (btrim(content) <> ''),
  -- Stesso invariante del costruttore Memory lato Dart: esattamente un owner
  -- valorizzato, coerente con level.
  constraint memories_owner_matches_level check (
    (level = 'global' and user_id is not null and workspace_id is null and chat_id is null) or
    (level = 'workspace' and workspace_id is not null and user_id is null and chat_id is null) or
    (level = 'conversation' and chat_id is not null and user_id is null and workspace_id is null)
  )
);

comment on table public.memories is
  'Domain Model, entita'' Memory (docs/product/12-domain-model.md). Prima slice: solo '
  'livello globale, valorizzato dall''AI Engine su richiesta esplicita dell''utente '
  '("ricorda che...").';

create index if not exists memories_user_id_idx on public.memories (user_id)
  where user_id is not null;

alter table public.memories enable row level security;

-- Solo livello globale in questa slice: owner_id = auth.uid() diretto, senza il
-- pattern a join su workspaces usato da notes/tasks (qui non c'e' un Workspace).
create policy "memories_select_own_global"
  on public.memories for select
  using (level = 'global' and user_id = auth.uid());

create policy "memories_insert_own_global"
  on public.memories for insert
  with check (level = 'global' and user_id = auth.uid());

create policy "memories_delete_own_global"
  on public.memories for delete
  using (level = 'global' and user_id = auth.uid());

grant select, insert, delete on public.memories to authenticated;
