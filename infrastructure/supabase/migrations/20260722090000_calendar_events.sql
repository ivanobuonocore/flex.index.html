-- Fase 3, "Promemoria via Chat" (CLAUDE.md — richiesta esplicita dell'utente: notifiche
-- push vere per i promemoria, non un semplice elenco in app — l'infrastruttura di
-- consegna era già stata costruita e provata nella slice `push_subscriptions`/
-- `send-test-push`). Stesso pattern RLS a join di notes/tasks: nessuna colonna owner_id
-- diretta, appartenenza verificata via EXISTS sul Workspace referenziato.

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  duration_minutes integer not null default 30 check (duration_minutes > 0),
  reminder_minutes_before integer check (reminder_minutes_before >= 0),
  -- Nullable: valorizzati solo se l'evento deriva da una Task o da un messaggio di Chat.
  source_task_id uuid references public.tasks (id) on delete set null,
  source_chat_id uuid references public.chats (id) on delete set null,
  created_at timestamptz not null default now(),
  -- Impostato dalla Edge Function send-due-reminders non appena la notifica push è
  -- stata inviata: evita di inviarla due volte allo stesso evento (il cron gira ogni
  -- minuto e altrimenti rivedrebbe lo stesso evento scaduto ad ogni esecuzione).
  notified_at timestamptz,
  deleted_at timestamptz,
  constraint calendar_events_title_not_blank check (btrim(title) <> '')
);

comment on table public.calendar_events is
  'Domain Model, entita'' Calendar Event (docs/product/12-domain-model.md). Prima '
  'implementazione reale in Fase 3, "Promemoria via Chat". notified_at distingue un '
  'promemoria già notificato da uno ancora da inviare — non è uno stato di conferma '
  'come Transaction.status: qui non c''e nulla da confermare, solo da consegnare.';

create index if not exists calendar_events_workspace_id_idx
  on public.calendar_events (workspace_id);
-- Interrogato da send-due-reminders (starts_at <= now() and notified_at is null): un
-- indice sulla sola starts_at basta, la funzione filtra su tutti i Workspace di ogni
-- utente (service role, non un singolo Workspace).
create index if not exists calendar_events_starts_at_idx
  on public.calendar_events (starts_at)
  where notified_at is null and deleted_at is null;

alter publication supabase_realtime add table public.calendar_events;

alter table public.calendar_events enable row level security;

create policy "calendar_events_select_own_workspace"
  on public.calendar_events for select
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = calendar_events.workspace_id and w.owner_id = auth.uid()
  ));

create policy "calendar_events_insert_own_workspace"
  on public.calendar_events for insert
  to authenticated
  with check (exists (
    select 1 from public.workspaces w
    where w.id = calendar_events.workspace_id and w.owner_id = auth.uid()
  ));

create policy "calendar_events_update_own_workspace"
  on public.calendar_events for update
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = calendar_events.workspace_id and w.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspaces w
    where w.id = calendar_events.workspace_id and w.owner_id = auth.uid()
  ));

create policy "calendar_events_delete_own_workspace"
  on public.calendar_events for delete
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = calendar_events.workspace_id and w.owner_id = auth.uid()
  ));

-- `send-due-reminders` (infrastructure/supabase/functions/send-due-reminders) è l'unica
-- function di questo progetto che usa la service role, non il JWT di un utente: è
-- invocata da un cron job Postgres (pg_cron), non da una richiesta HTTP di un utente
-- autenticato — non esiste un JWT da inoltrare. Deve poter leggere calendar_events di
-- TUTTI gli utenti (per trovare i promemoria scaduti) e le rispettive push_subscriptions
-- per inviare la notifica: la service role bypassa le RLS sopra by design, la function
-- stessa filtra correttamente per non notificare due volte lo stesso evento.
--
-- pg_cron/pg_net non sono abilitate di default: vanno attivate manualmente (Database →
-- Extensions, nel pannello Supabase) prima di eseguire quanto segue. Il secret
-- `service_role_key` va sostituito con la Service Role Key del progetto (Project
-- Settings → API) — non è la stessa cosa della chiave anonima usata dal client.
--
-- select cron.schedule(
--   'send-due-reminders',
--   '* * * * *', -- ogni minuto
--   $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-due-reminders',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'Authorization', 'Bearer <SERVICE_ROLE_KEY>'
--     ),
--     body := '{}'::jsonb
--   );
--   $$
-- );
