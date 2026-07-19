-- Fase 3 (slice 1): Chat e Message (docs/product/12-domain-model.md). Prima migrazione
-- che introduce l'AI Engine: queste tabelle sono lette/scritte anche dalla Edge Function
-- `ai-chat` (infrastructure/supabase/functions/ai-chat), sempre con il JWT dell'utente
-- (mai la service role) — le RLS qui sotto si applicano identiche sia al client mobile
-- sia alla function.

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  -- Nullable: una Chat può esistere senza Workspace (Domain Model, entità Chat —
  -- "privata, collegata a un Workspace, condivisa"). Per questo l'isolamento usa
  -- owner_id diretto, non un join come notes/tasks/documents.
  workspace_id uuid references public.workspaces (id) on delete set null,
  title text not null,
  ai_model text not null,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  constraint chats_title_not_blank check (btrim(title) <> '')
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  role text not null check (role in ('user', 'ai', 'system')),
  content text not null,
  attachment_ids text[] not null default '{}',
  tokens_used integer,
  -- Note/Task incluse nel contesto Workspace per generare la risposta (AI Constitution,
  -- Principio 3 — Trasparenza). Popolato dalla Edge Function, mai dal client.
  source_references text[] not null default '{}',
  created_at timestamptz not null default now(),
  constraint messages_content_not_blank check (btrim(content) <> '')
);

comment on table public.chats is 'Domain Model, entita'' Chat (docs/product/12-domain-model.md).';
comment on table public.messages is
  'Domain Model, entita'' Message. Scritta sia dal client (messaggio utente) sia dalla '
  'Edge Function ai-chat (risposta assistente), sempre con RLS invariata.';

create index if not exists chats_owner_id_idx on public.chats (owner_id);
create index if not exists chats_owner_activity_idx
  on public.chats (owner_id, coalesce(last_message_at, created_at) desc);
create index if not exists chats_workspace_id_idx on public.chats (workspace_id)
  where workspace_id is not null;

create index if not exists messages_chat_id_idx on public.messages (chat_id);
create index if not exists messages_chat_created_idx on public.messages (chat_id, created_at);

alter publication supabase_realtime add table public.chats;
alter publication supabase_realtime add table public.messages;

alter table public.chats enable row level security;
alter table public.messages enable row level security;

create policy "chats_select_own"
  on public.chats for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "chats_insert_own"
  on public.chats for insert
  to authenticated
  with check (auth.uid() = owner_id);

create policy "chats_update_own"
  on public.chats for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Nessuna colonna owner_id diretta su messages: l'appartenenza si verifica tramite la
-- Chat referenziata, stesso pattern EXISTS di notes/tasks/documents.
create policy "messages_select_own_chat"
  on public.messages for select
  to authenticated
  using (exists (
    select 1 from public.chats c
    where c.id = messages.chat_id and c.owner_id = auth.uid()
  ));

create policy "messages_insert_own_chat"
  on public.messages for insert
  to authenticated
  with check (exists (
    select 1 from public.chats c
    where c.id = messages.chat_id and c.owner_id = auth.uid()
  ));

-- SECURITY INVOKER esplicito (coerente con search_workspace_content): il trigger gira
-- con i privilegi di chi ha inserito il messaggio, che possiede già la Chat (altrimenti
-- l'insert su messages sarebbe già stato bloccato dalla RLS sopra) — nessun privilegio
-- aggiuntivo necessario.
create or replace function public.touch_chat_last_message()
returns trigger
language plpgsql
security invoker
as $$
begin
  update public.chats set last_message_at = new.created_at where id = new.chat_id;
  return new;
end;
$$;

create trigger messages_touch_chat_last_message
  after insert on public.messages
  for each row
  execute function public.touch_chat_last_message();
