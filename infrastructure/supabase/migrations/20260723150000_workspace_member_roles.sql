-- Permessi granulari (viewer/editor) sui Workspace condivisi (integrazione richiesta
-- esplicitamente, dopo che "Bilancio condiviso" e "Note/Attività condivise" avevano dato a ogni
-- membro sempre gli stessi diritti del proprietario). Additiva nello spirito (nessuna tabella
-- nuova, nessuna policy di lettura toccata: un viewer deve continuare a leggere tutto) ma
-- necessariamente sostitutiva sulle policy di scrittura, che vanno ristrette — non si può
-- aggiungerne una nuova in OR senza vanificare la restrizione.

alter table public.workspace_members
  add column if not exists role text not null default 'editor'
    check (role in ('viewer', 'editor'));

comment on column public.workspace_members.role is
  'editor: stessi diritti di scrittura del proprietario su Transazioni/Note/Attività di questo '
  'Workspace. viewer: sola lettura. Default ''editor'' per non cambiare il comportamento dei '
  'membri esistenti (creati prima di questa migrazione, tutti con accesso in scrittura).';

-- Solo il proprietario può cambiare il ruolo di un membro (nessuna policy insert: il ruolo iniziale
-- si stabilisce solo tramite redeem_workspace_invite, mai da un insert diretto del client).
create policy "workspace_members_update_owner"
  on public.workspace_members for update
  to authenticated
  using (public.is_workspace_owner(workspace_id))
  with check (public.is_workspace_owner(workspace_id));

-- Il ruolo che verrà assegnato al momento del redeem: deciso dal proprietario quando genera
-- l'invito, non dal chiamante di redeem_workspace_invite (che non deve poter auto-assegnarsi
-- 'editor' passando un parametro libero).
alter table public.workspace_invites
  add column if not exists role text not null default 'editor'
    check (role in ('viewer', 'editor'));

comment on column public.workspace_invites.role is
  'Ruolo che redeem_workspace_invite assegna in workspace_members al momento del redeem — scelto '
  'dal proprietario alla creazione dell''invito, non dal chiamante di redeem.';

-- Rimpiazza le policy di scrittura su transactions/notes/tasks (introdotte rispettivamente da
-- 20260721160000_workspace_sharing.sql e 20260723130000_shared_workspace_notes_tasks.sql) per
-- richiedere role = 'editor', oltre alla sola appartenenza. Le policy di select restano invariate
-- (mai toccate qui): un viewer deve continuare a leggere tutto.

drop policy if exists "transactions_insert_member" on public.transactions;
create policy "transactions_insert_member"
  on public.transactions for insert
  to authenticated
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "transactions_update_member" on public.transactions;
create policy "transactions_update_member"
  on public.transactions for update
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ))
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "transactions_delete_member" on public.transactions;
create policy "transactions_delete_member"
  on public.transactions for delete
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = transactions.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "notes_insert_member" on public.notes;
create policy "notes_insert_member"
  on public.notes for insert
  to authenticated
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "notes_update_member" on public.notes;
create policy "notes_update_member"
  on public.notes for update
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ))
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "notes_delete_member" on public.notes;
create policy "notes_delete_member"
  on public.notes for delete
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "tasks_insert_member" on public.tasks;
create policy "tasks_insert_member"
  on public.tasks for insert
  to authenticated
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "tasks_update_member" on public.tasks;
create policy "tasks_update_member"
  on public.tasks for update
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ))
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

drop policy if exists "tasks_delete_member" on public.tasks;
create policy "tasks_delete_member"
  on public.tasks for delete
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id
      and m.user_id = auth.uid()
      and m.role = 'editor'
  ));

-- redeem_workspace_invite ora assegna il ruolo portato dall'invito, non sempre 'editor' come
-- implicito prima di questa migrazione (ridefinizione completa della funzione, stessa firma).
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

  insert into public.workspace_members (workspace_id, user_id, role)
    values (v_invite.workspace_id, auth.uid(), v_invite.role)
    on conflict (workspace_id, user_id) do nothing;

  update public.workspace_invites
    set used_at = now(), used_by = auth.uid()
    where id = v_invite.id;

  return v_invite.workspace_id;
end;
$$;
