-- Memoria — livello Workspace (Domain Model, entità Memory). Estende
-- `20260722180000_memories.sql`, che aveva già lo schema per tutti e 3 i
-- livelli ma esponeva solo il Globale via RLS. Nessuna nuova colonna: solo le
-- policy mancanti per `level = 'workspace'`.
--
-- A differenza del Globale (scritto solo dall'AI Engine, "ricorda che..."), il
-- livello Workspace è creato manualmente dall'utente in questa slice: "Chat
-- unica" (20260719103109_chats_and_messages.sql + task Slice 7B) ha reso la
-- Chat un'unica conversazione globale per utente, non più scopata a un
-- singolo Workspace — l'AI Engine non ha quindi modo di sapere a quale
-- Workspace collegare un ricordo pronunciato in Chat. Il livello
-- Conversazione resta fuori scope per lo stesso motivo, in forma più
-- radicale: con un'unica conversazione per utente, "per questa conversazione"
-- coinciderebbe sempre con "Globale" — nessun valore reale da costruire ora.
create index if not exists memories_workspace_id_idx on public.memories (workspace_id)
  where workspace_id is not null;

create policy "memories_select_own_workspace"
  on public.memories for select
  using (
    level = 'workspace' and exists (
      select 1 from public.workspaces w
      where w.id = memories.workspace_id and w.owner_id = auth.uid()
    )
  );

create policy "memories_insert_own_workspace"
  on public.memories for insert
  with check (
    level = 'workspace' and exists (
      select 1 from public.workspaces w
      where w.id = memories.workspace_id and w.owner_id = auth.uid()
    )
  );

create policy "memories_delete_own_workspace"
  on public.memories for delete
  using (
    level = 'workspace' and exists (
      select 1 from public.workspaces w
      where w.id = memories.workspace_id and w.owner_id = auth.uid()
    )
  );
