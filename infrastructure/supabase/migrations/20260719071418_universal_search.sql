-- Fase 2 (slice 3): Ricerca Universale (docs/product/06-information-architecture.md,
-- "Ricerca"). Full-text search cross-tabella su workspaces/notes/tasks/documents tramite
-- una singola funzione SQL, invece di 4 query separate lato client.

-- Config 'simple' (nessuno stemming linguistico): i contenuti dell'utente non sono
-- garantiti in una sola lingua, 'simple' evita di assumerne una.
create index if not exists workspaces_search_idx on public.workspaces
  using gin (to_tsvector('simple', name || ' ' || coalesce(description, '')));

create index if not exists notes_search_idx on public.notes
  using gin (to_tsvector('simple', title || ' ' || coalesce(content, '')));

create index if not exists tasks_search_idx on public.tasks
  using gin (to_tsvector('simple', title || ' ' || coalesce(description, '')));

-- I nomi file spesso contengono '_' o '.' (es. SupabaseDocumentRepository sanitizza i nomi
-- caricati sostituendo i caratteri non alfanumerici con '_'). Il parser di 'simple' tratta
-- "contratto_alfa.pdf" come un unico lessema, quindi cercare "contratto" non lo troverebbe
-- senza normalizzare la punteggiatura in spazi prima della tokenizzazione (verificato
-- manualmente: senza questa normalizzazione la ricerca non trovava i propri documenti).
create index if not exists documents_search_idx on public.documents
  using gin (to_tsvector('simple', regexp_replace(name, '[_.]', ' ', 'g')));

-- SECURITY INVOKER (esplicito, non solo il default): la funzione gira con i privilegi di
-- chi chiama, quindi le policy RLS di ciascuna tabella si applicano automaticamente alle
-- SELECT al suo interno — nessun filtro owner_id/EXISTS duplicato qui. Verificato
-- manualmente che un utente non veda contenuti di un Workspace altrui tramite questa
-- funzione, esattamente come le tabelle sottostanti (vedi docs/database/README.md).
create or replace function public.search_workspace_content(query text)
returns table (
  result_type text,
  id uuid,
  workspace_id uuid,
  title text,
  snippet text
)
language sql
stable
security invoker
as $$
  select 'workspace'::text, w.id, w.id, w.name, w.description
  from public.workspaces w
  where w.deleted_at is null
    and to_tsvector('simple', w.name || ' ' || coalesce(w.description, ''))
        @@ websearch_to_tsquery('simple', query)

  union all

  select 'note'::text, n.id, n.workspace_id, n.title, left(n.content, 200)
  from public.notes n
  where n.deleted_at is null
    and to_tsvector('simple', n.title || ' ' || coalesce(n.content, ''))
        @@ websearch_to_tsquery('simple', query)

  union all

  select 'task'::text, t.id, t.workspace_id, t.title, t.description
  from public.tasks t
  where t.deleted_at is null
    and to_tsvector('simple', t.title || ' ' || coalesce(t.description, ''))
        @@ websearch_to_tsquery('simple', query)

  union all

  select 'document'::text, d.id, d.workspace_id, d.name, d.mime_type
  from public.documents d
  where d.deleted_at is null
    and to_tsvector('simple', regexp_replace(d.name, '[_.]', ' ', 'g'))
        @@ websearch_to_tsquery('simple', query)
$$;

comment on function public.search_workspace_content(text) is
  'Ricerca Universale (docs/product/06-information-architecture.md). SECURITY INVOKER: '
  'l''isolamento tra utenti dipende dalle RLS di workspaces/notes/tasks/documents, non da '
  'un filtro qui dentro — vedi il commento sopra la definizione.';

grant execute on function public.search_workspace_content(text) to authenticated;
