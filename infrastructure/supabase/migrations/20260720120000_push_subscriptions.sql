-- Fase 3 (slice 4): Notifiche push vere (docs/product/12-domain-model.md non le modella
-- come entità a sé: sono infrastruttura di consegna, non un dato di prodotto). Livello
-- account, non Workspace — una notifica non appartiene a un singolo Workspace, come
-- `chats`/`workspaces` (owner_id diretto, non un join).

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Un endpoint identifica univocamente l'abbonamento push del browser: la stessa
  -- combinazione utente+dispositivo non deve produrre righe duplicate.
  endpoint text not null unique,
  p256dh text not null,
  auth_key text not null,
  created_at timestamptz not null default now(),
  constraint push_subscriptions_endpoint_not_blank check (btrim(endpoint) <> ''),
  constraint push_subscriptions_p256dh_not_blank check (btrim(p256dh) <> ''),
  constraint push_subscriptions_auth_key_not_blank check (btrim(auth_key) <> '')
);

comment on table public.push_subscriptions is
  'Iscrizioni Web Push (RFC 8291) dell''utente, lette dalla Edge Function send-test-push '
  'per l''invio; scritte dal client dopo Notification.requestPermission() + '
  'pushManager.subscribe().';

create index if not exists push_subscriptions_user_id_idx
  on public.push_subscriptions (user_id);

alter table public.push_subscriptions enable row level security;

create policy "push_subscriptions_select_own"
  on public.push_subscriptions for select
  to authenticated
  using (auth.uid() = user_id);

create policy "push_subscriptions_insert_own"
  on public.push_subscriptions for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "push_subscriptions_update_own"
  on public.push_subscriptions for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "push_subscriptions_delete_own"
  on public.push_subscriptions for delete
  to authenticated
  using (auth.uid() = user_id);
