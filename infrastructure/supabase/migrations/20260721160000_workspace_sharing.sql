-- Fase 3, "Bilancio condiviso" (CLAUDE.md — richiesta esplicita dell'utente: due Bilanci
-- separati, uno personale e uno condiviso con un'altra persona che ha un proprio account).
-- Non introduce Workspace condivisi in generale: un Bilancio condiviso è semplicemente un
-- Workspace "libero" (non una sezione fissa) a cui un secondo utente viene ammesso tramite
-- invito. Le policy qui sotto sono ADDITIVE — policy RLS permissive separate, che Postgres
-- combina in OR con quelle già esistenti su `workspaces`/`transactions` (mai toccate) — esattamente
-- come anticipato dal commento nella prima migrazione ("i Workspace condivisi richiederanno una
-- tabella di membership e policy aggiuntive, non una riscrittura di queste").
--
-- Scope volutamente ridotto (risposta esplicita dell'utente): solo le Transazioni sono condivise.
-- Note/Attività/Documenti restano visibili solo al proprietario, anche per un Workspace di cui
-- qualcun altro è membro — le loro policy RLS non vengono toccate da questa migrazione. Solo le
-- transazioni future sono condivise: non c'è alcuna migrazione dei dati storici.

create table if not exists public.workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);

comment on table public.workspace_members is
  'Fase 3, "Bilancio condiviso". Un membro (diverso dal proprietario) di un Workspace: dà accesso '
  'solo alle Transazioni di quel Workspace (RLS aggiuntiva su transactions), non a Note/Attività/'
  'Documenti (invariate).';

create index if not exists workspace_members_workspace_id_idx
  on public.workspace_members (workspace_id);
create index if not exists workspace_members_user_id_idx
  on public.workspace_members (user_id);

create table if not exists public.workspace_invites (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  -- 8 caratteri esadecimali maiuscoli, facili da leggere/condividere a voce o per messaggio.
  code text not null unique default upper(substr(md5(gen_random_uuid()::text), 1, 8)),
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  used_by uuid references auth.users (id) on delete set null
);

comment on table public.workspace_invites is
  'Fase 3, "Bilancio condiviso". Codice d''invito a uso singolo per un Workspace: consumato tramite '
  'la funzione redeem_workspace_invite, mai inserito/letto direttamente dal client per il redeem '
  '(niente policy insert/select per il membro su questa tabella).';

create index if not exists workspace_invites_workspace_id_idx
  on public.workspace_invites (workspace_id);

alter publication supabase_realtime add table public.workspace_members;

alter table public.workspace_members enable row level security;
alter table public.workspace_invites enable row level security;

-- SECURITY DEFINER (non invoker): usata dalle policy sotto per verificare la proprietà di un
-- Workspace SENZA passare dalla RLS di `workspaces` — se lo facessero con una query diretta, si
-- creerebbe una dipendenza circolare (verificato: "infinite recursion detected in policy for
-- relation workspaces" su Postgres locale). `workspaces_select_member` (sotto) interroga
-- `workspace_members`; se una policy di `workspace_members` interrogasse a sua volta `workspaces`
-- sotto RLS, la valutazione di `workspaces` richiederebbe `workspace_members`, che richiederebbe
-- di nuovo `workspaces`, all'infinito. Questa funzione rompe il ciclo: gira con i privilegi di chi
-- l'ha creata (il proprietario del progetto Supabase, che possiede anche `workspaces` e quindi
-- bypassa la RLS su quella tabella), non con quelli del chiamante.
create or replace function public.is_workspace_owner(p_workspace_id uuid) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspaces w
    where w.id = p_workspace_id and w.owner_id = auth.uid()
  );
$$;

comment on function public.is_workspace_owner(uuid) is
  'Fase 3, "Bilancio condiviso". SECURITY DEFINER per rompere la dipendenza circolare fra le RLS '
  'di workspaces e workspace_members — vedi il commento sopra la definizione.';

grant execute on function public.is_workspace_owner(uuid) to authenticated;

-- workspace_members: il proprietario del Workspace gestisce i membri (select per vedere chi c'è,
-- delete per rimuoverli); un membro può leggere solo la propria riga (per sapere di essere membro
-- di quel Workspace). Nessuna policy insert per il ruolo authenticated: l'unico modo di diventare
-- membro è redeem_workspace_invite (security definer, bypassa la RLS).
create policy "workspace_members_select_owner"
  on public.workspace_members for select
  to authenticated
  using (public.is_workspace_owner(workspace_id));

create policy "workspace_members_select_self"
  on public.workspace_members for select
  to authenticated
  using (user_id = auth.uid());

create policy "workspace_members_delete_owner"
  on public.workspace_members for delete
  to authenticated
  using (public.is_workspace_owner(workspace_id));

-- workspace_invites: solo il proprietario del Workspace crea/vede/revoca i propri inviti. Un
-- invitato non ha mai una policy select qui: la validazione del codice passa dalla funzione
-- security definer sotto, che agisce con privilegi elevati solo per quello scopo preciso.
create policy "workspace_invites_select_owner"
  on public.workspace_invites for select
  to authenticated
  using (created_by = auth.uid());

create policy "workspace_invites_insert_owner"
  on public.workspace_invites for insert
  to authenticated
  with check (
    created_by = auth.uid()
    and public.is_workspace_owner(workspace_id)
  );

create policy "workspace_invites_delete_owner"
  on public.workspace_invites for delete
  to authenticated
  using (created_by = auth.uid());

-- Estensione ADDITIVA (nuove policy permissive, si sommano in OR) di `workspaces`: un membro deve
-- poter vedere il Workspace condiviso nella propria lista, non solo il proprietario.
create policy "workspaces_select_member"
  on public.workspaces for select
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = workspaces.id and m.user_id = auth.uid()
  ));

-- Estensione ADDITIVA di `transactions`: un membro può leggere/scrivere le transazioni del
-- Workspace condiviso esattamente come farebbe il proprietario. Nessuna policy equivalente viene
-- aggiunta su notes/tasks/documents: restano visibili solo al proprietario, per scelta esplicita
-- dell'utente ("Solo il Bilancio").
create policy "transactions_select_member"
  on public.transactions for select
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id and m.user_id = auth.uid()
  ));

create policy "transactions_insert_member"
  on public.transactions for insert
  to authenticated
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id and m.user_id = auth.uid()
  ));

create policy "transactions_update_member"
  on public.transactions for update
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id and m.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id and m.user_id = auth.uid()
  ));

create policy "transactions_delete_member"
  on public.transactions for delete
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id and m.user_id = auth.uid()
  ));

-- SECURITY DEFINER (non invoker, a differenza di search_workspace_content): l'utente che redime un
-- invito non ha (e non deve avere) una policy select su workspace_invites per trovare la riga
-- tramite il codice — questa funzione è l'unico modo per farlo, con validazione esplicita dentro
-- la funzione stessa (non un semplice passthrough di privilegi). Ritorna solo l'id del Workspace,
-- non anche il nome: dopo l'insert in workspace_members, il client può leggere il Workspace
-- completo tramite la normale `watchWorkspaces()` (RLS `workspaces_select_member`, sopra, lo rende
-- visibile da questo momento) — un secondo canale di lettura duplicherebbe quello già esistente.
create or replace function public.redeem_workspace_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite record;
begin
  select * into v_invite
    from public.workspace_invites
    where code = p_code
    for update;

  if not found then
    raise exception 'Codice d''invito non valido.';
  end if;

  if v_invite.used_at is not null then
    raise exception 'Questo codice d''invito è già stato usato.';
  end if;

  if v_invite.expires_at <= now() then
    raise exception 'Questo codice d''invito è scaduto.';
  end if;

  if v_invite.created_by = auth.uid() then
    raise exception 'Non puoi unirti a un Bilancio condiviso creato da te.';
  end if;

  insert into public.workspace_members (workspace_id, user_id)
    values (v_invite.workspace_id, auth.uid())
    on conflict (workspace_id, user_id) do nothing;

  update public.workspace_invites
    set used_at = now(), used_by = auth.uid()
    where id = v_invite.id;

  return v_invite.workspace_id;
end;
$$;

comment on function public.redeem_workspace_invite(text) is
  'Fase 3, "Bilancio condiviso". SECURITY DEFINER intenzionale: valida il codice (esistente, non '
  'scaduto, non già usato, non creato dallo stesso utente che lo sta redimendo) e inserisce la '
  'riga in workspace_members per conto dell''utente autenticato (auth.uid()), mai per conto di '
  'altri — l''unico input esterno è il codice stesso.';

grant execute on function public.redeem_workspace_invite(text) to authenticated;
