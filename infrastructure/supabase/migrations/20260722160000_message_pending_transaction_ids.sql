-- Conferma/Scarta inline in Chat (richiesta esplicita dell'utente): collega un
-- messaggio dell'assistente alle Transazioni pending che ha generato, così la Chat
-- può mostrare Conferma/Scarta subito sotto la risposta, senza dover aprire il
-- Bilancio. Stessa convenzione già usata per attachment_ids/source_references
-- (text[], non un vero array di FK: niente vincolo referenziale qui).

alter table public.messages
  add column if not exists pending_transaction_ids text[] not null default '{}';

comment on column public.messages.pending_transaction_ids is
  'Id delle Transazioni pending create da questo messaggio (ai-chat, extract_transactions) — '
  'permette alla Chat di mostrare Conferma/Scarta inline. Non aggiornata quando le transazioni '
  'vengono confermate/scartate altrove: il client filtra per status=pending al momento della '
  'lettura, un id che punta a una transazione già decisa viene semplicemente ignorato.';
