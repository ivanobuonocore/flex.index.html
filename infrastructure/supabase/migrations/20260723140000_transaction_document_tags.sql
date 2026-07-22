-- Tag su Transazioni e Documenti (richiesta esplicita dell'utente, integrazione suggerita e
-- confermata): stesso pattern già usato per le Note (20260718235106_notes_and_tasks.sql) — un
-- text[] libero, nessuna tabella di lookup, gestito solo dal client (mai dall'AI: i tag restano
-- una scelta manuale dell'utente, extract_transactions in ai-chat non li tocca).

alter table public.transactions
  add column if not exists tags text[] not null default '{}';

alter table public.documents
  add column if not exists tags text[] not null default '{}';

comment on column public.transactions.tags is
  'Tag liberi assegnati manualmente dall''utente (mai dall''AI Engine) — stesso pattern di notes.tags.';

comment on column public.documents.tags is
  'Tag liberi assegnati manualmente dall''utente — stesso pattern di notes.tags.';
