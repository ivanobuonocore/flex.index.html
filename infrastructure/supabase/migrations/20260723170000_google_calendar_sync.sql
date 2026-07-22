-- Sync con Google Calendar (Fase 3, "Sync con Google Calendar" — integrazione richiesta
-- esplicitamente). Due parti additive:
-- 1) calendar_connections: un account Google collegato per utente (livello account, come
--    push_subscriptions), mai letto dal client mobile direttamente — solo tramite
--    get_my_calendar_connection() (sotto), che non espone mai google_refresh_token.
-- 2) calendar_events.google_event_id: collega ogni evento al suo gemello su Google, per non
--    risincronizzare all'infinito in nessuna delle due direzioni (push e pull).

create table if not exists public.calendar_connections (
  user_id uuid primary key references auth.users (id) on delete cascade,
  google_refresh_token text not null,
  google_calendar_id text not null default 'primary',
  sync_token text,
  last_synced_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.calendar_connections is
  'Collegamento Google Calendar per utente. google_refresh_token non è mai letto dal client '
  'mobile: le Edge Function (sync-calendar-event, pull-google-calendar-events) lo leggono sotto '
  'RLS con il JWT del proprietario o, per pull-google-calendar-events, con la service role '
  '(deve scorrere tutti gli utenti collegati, non solo il chiamante). Lo stato "connesso" che '
  'il client mostra viene letto tramite get_my_calendar_connection(), mai da questa tabella '
  'direttamente.';

alter table public.calendar_connections enable row level security;

create policy "calendar_connections_select_own" on public.calendar_connections
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "calendar_connections_insert_own" on public.calendar_connections
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "calendar_connections_update_own" on public.calendar_connections
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "calendar_connections_delete_own" on public.calendar_connections
  for delete
  to authenticated
  using (user_id = auth.uid());

-- Funzione security definer: restituisce solo i campi non sensibili della connessione
-- dell'utente corrente. Il `where user_id = auth.uid()` la rende sicura nonostante
-- security definer (mai un modo per leggere la riga di un altro utente) — stesso principio
-- già usato per is_workspace_owner/redeem_workspace_invite in questo progetto. Non un'alternativa
-- alla RLS della tabella (che resta comunque attiva per le Edge Function), solo un modo per il
-- client mobile di non dover mai fare una query sulla tabella con il token.
create or replace function public.get_my_calendar_connection()
returns table (
  google_calendar_id text,
  last_synced_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select google_calendar_id, last_synced_at, created_at
  from public.calendar_connections
  where user_id = auth.uid();
$$;

grant execute on function public.get_my_calendar_connection() to authenticated;

alter table public.calendar_events add column if not exists google_event_id text;

comment on column public.calendar_events.google_event_id is
  'Id dell''evento gemello su Google Calendar. Scritto solo dalla Edge Function '
  'sync-calendar-event, mai dal client; pull-google-calendar-events ignora un evento Google il '
  'cui id è già presente qui, per non creare un loop tra le due direzioni di sync.';

-- pull-google-calendar-events gira via pg_cron/pg_net (service role, come send-due-reminders):
-- non abilitati di default, richiedono un passo manuale nel dashboard Supabase — vedi
-- infrastructure/supabase/README.md. Esempio (Project Ref/Service Role Key da sostituire):
--
-- select cron.schedule(
--   'pull-google-calendar-events',
--   '*/10 * * * *', -- ogni 10 minuti
--   $$
--   select net.http_post(
--     url := 'https://<PROJECT_REF>.supabase.co/functions/v1/pull-google-calendar-events',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'Authorization', 'Bearer <SERVICE_ROLE_KEY>'
--     ),
--     body := '{}'::jsonb
--   );
--   $$
-- );
