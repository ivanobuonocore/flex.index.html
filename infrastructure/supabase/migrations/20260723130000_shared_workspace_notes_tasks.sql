-- Fase 3, "Note/Attività condivise" (richiesta esplicita dell'utente: estendere il modello di
-- condivisione — finora solo il Bilancio, vedi 20260721160000_workspace_sharing.sql — a Note e
-- Attività, con gli stessi permessi di lettura+scrittura). Non introduce un meccanismo nuovo: le
-- tabelle workspace_members/workspace_invites sono già generiche per Workspace, la migrazione
-- precedente aveva deliberatamente ridotto lo scope alle sole Transazioni ("risposta esplicita
-- dell'utente, 'Solo il Bilancio'") — questa migrazione allarga quello scope, restando ADDITIVA
-- (nuove policy permissive, combinate in OR con quelle esistenti su notes/tasks, mai toccate).
--
-- Documenti restano esclusi (fuori dallo scope di questa richiesta, non menzionati): un membro non
-- vede/carica Documenti del Workspace condiviso, solo Note/Attività/Transazioni.

create policy "notes_select_member"
  on public.notes for select
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id and m.user_id = auth.uid()
  ));

create policy "notes_insert_member"
  on public.notes for insert
  to authenticated
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id and m.user_id = auth.uid()
  ));

create policy "notes_update_member"
  on public.notes for update
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id and m.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id and m.user_id = auth.uid()
  ));

create policy "notes_delete_member"
  on public.notes for delete
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = notes.workspace_id and m.user_id = auth.uid()
  ));

create policy "tasks_select_member"
  on public.tasks for select
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id and m.user_id = auth.uid()
  ));

create policy "tasks_insert_member"
  on public.tasks for insert
  to authenticated
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id and m.user_id = auth.uid()
  ));

create policy "tasks_update_member"
  on public.tasks for update
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id and m.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id and m.user_id = auth.uid()
  ));

create policy "tasks_delete_member"
  on public.tasks for delete
  to authenticated
  using (exists (
    select 1 from public.workspace_members m
    where m.workspace_id = tasks.workspace_id and m.user_id = auth.uid()
  ));

comment on table public.workspace_members is
  'Fase 3, "Bilancio condiviso" + "Note/Attività condivise". Un membro (diverso dal proprietario) '
  'di un Workspace: dà accesso a Transazioni, Note e Attività di quel Workspace (RLS aggiuntiva su '
  'ciascuna tabella), non ai Documenti (invariati, restano visibili solo al proprietario).';
