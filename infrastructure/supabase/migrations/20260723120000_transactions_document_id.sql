-- Scontrino/ricevuta allegata a una Transazione (Domain Model — richiesta esplicita
-- dell'utente: "scontrino allegato alla Transazione"). A differenza della foto che l'AI
-- legge in Chat per estrarre l'importo (solo temporanea, mai persistita come Document),
-- questo collega un Document persistente e consultabile dopo. Nessuna nuova RLS: la
-- colonna è protetta dalle policy già esistenti su `transactions`
-- (20260719150000_transactions.sql, più le policy additive di
-- 20260721160000_workspace_sharing.sql per il Bilancio condiviso).
alter table public.transactions
  add column if not exists document_id uuid references public.documents (id) on delete set null;

comment on column public.transactions.document_id is
  'Scontrino/ricevuta allegata (Document persistente), facoltativa. Vedi '
  'docs/database/README.md.';

create index if not exists transactions_document_id_idx on public.transactions (document_id)
  where document_id is not null;
