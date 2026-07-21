-- Ricerca Universale: estende search_workspace_content a Transazioni e Promemoria
-- (richiesta esplicita dell'utente). Le transazioni "pending" restano escluse: sono
-- suggerimenti dell'AI non ancora decisi dall'utente (AI Constitution, Principio 1),
-- non ancora un dato "reale" da poter ritrovare in ricerca.

create index if not exists transactions_search_idx on public.transactions
  using gin (to_tsvector('simple', description));

create index if not exists calendar_events_search_idx on public.calendar_events
  using gin (to_tsvector('simple', title));

-- SECURITY INVOKER, stesso pattern della definizione originale
-- (20260719071418_universal_search.sql): l'isolamento dipende dalle RLS di
-- transactions/calendar_events, non da un filtro qui dentro.
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

  union all

  select 'transaction'::text, tr.id, tr.workspace_id, tr.description,
    (case when tr.type = 'income' then '+' else '-' end) ||
      to_char(tr.amount_cents / 100.0, 'FM999999990.00')
  from public.transactions tr
  where tr.status = 'confirmed'
    and to_tsvector('simple', tr.description)
        @@ websearch_to_tsquery('simple', query)

  union all

  select 'reminder'::text, ce.id, ce.workspace_id, ce.title,
    to_char(ce.starts_at, 'DD/MM/YYYY HH24:MI')
  from public.calendar_events ce
  where ce.deleted_at is null
    and to_tsvector('simple', ce.title)
        @@ websearch_to_tsquery('simple', query)
$$;

comment on function public.search_workspace_content(text) is
  'Ricerca Universale (docs/product/06-information-architecture.md). SECURITY INVOKER: '
  'l''isolamento tra utenti dipende dalle RLS di workspaces/notes/tasks/documents/'
  'transactions/calendar_events, non da un filtro qui dentro — vedi il commento sopra '
  'la definizione. Le transazioni pending sono escluse: sono suggerimenti dell''AI non '
  'ancora confermati dall''utente.';
