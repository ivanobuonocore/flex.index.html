-- Fase 2 (slice 2): Document (docs/product/12-domain-model.md). Prima migrazione che
-- tocca Supabase Storage oltre a Postgres: i file vivono nel bucket `documents`, questa
-- tabella conserva solo i metadata.

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name text not null,
  mime_type text not null,
  size_bytes bigint not null check (size_bytes >= 0),
  storage_path text not null unique,
  hash text not null,
  chat_id uuid,
  uploaded_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint documents_name_not_blank check (btrim(name) <> '')
);

comment on table public.documents is
  'Domain Model, entita'' Document (docs/product/12-domain-model.md). storage_path segue '
  'la convenzione {workspace_id}/{document_id}-{filename}, verificata dalle policy su '
  'storage.objects piu'' sotto. chat_id resta senza FK: la tabella chat non esiste ancora '
  '(Fase 3).';

create index if not exists documents_workspace_id_idx on public.documents (workspace_id);
create index if not exists documents_workspace_uploaded_idx
  on public.documents (workspace_id, uploaded_at desc);

alter publication supabase_realtime add table public.documents;

alter table public.documents enable row level security;

-- Stesso pattern di notes/tasks: l'appartenenza si verifica tramite il Workspace
-- referenziato, non tramite una colonna owner_id diretta.
create policy "documents_select_own_workspace"
  on public.documents for select
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = documents.workspace_id and w.owner_id = auth.uid()
  ));

create policy "documents_insert_own_workspace"
  on public.documents for insert
  to authenticated
  with check (exists (
    select 1 from public.workspaces w
    where w.id = documents.workspace_id and w.owner_id = auth.uid()
  ));

create policy "documents_update_own_workspace"
  on public.documents for update
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = documents.workspace_id and w.owner_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workspaces w
    where w.id = documents.workspace_id and w.owner_id = auth.uid()
  ));

create policy "documents_delete_own_workspace"
  on public.documents for delete
  to authenticated
  using (exists (
    select 1 from public.workspaces w
    where w.id = documents.workspace_id and w.owner_id = auth.uid()
  ));

-- Storage: bucket privato (mai un URL pubblico diretto, solo signed URL —
-- Architectural Principles, Principio 9, Sicurezza by Design).
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- I file vengono caricati con path "{workspace_id}/{document_id}-{filename}"
-- (apps/mobile, SupabaseDocumentRepository). storage.foldername(objects.name) restituisce
-- i segmenti di cartella dell'oggetto: il primo segmento è il workspace_id. `objects.name`
-- è qualificato esplicitamente: `workspaces` ha anch'essa una colonna `name`, e senza
-- qualificazione il riferimento si risolve verso la subquery invece che verso la riga
-- della policy (bug verificato manualmente su un Postgres locale prima di questa versione).
create policy "documents_storage_select_own_workspace"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.workspaces w
      where w.id::text = (storage.foldername(objects.name))[1] and w.owner_id = auth.uid()
    )
  );

create policy "documents_storage_insert_own_workspace"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'documents'
    and exists (
      select 1 from public.workspaces w
      where w.id::text = (storage.foldername(objects.name))[1] and w.owner_id = auth.uid()
    )
  );

create policy "documents_storage_delete_own_workspace"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'documents'
    and exists (
      select 1 from public.workspaces w
      where w.id::text = (storage.foldername(objects.name))[1] and w.owner_id = auth.uid()
    )
  );
