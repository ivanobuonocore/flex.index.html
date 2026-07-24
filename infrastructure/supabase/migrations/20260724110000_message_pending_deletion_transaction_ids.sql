-- Richieste di eliminazione confermate direttamente nella Chat. La lista
-- contiene solo candidati: la cancellazione avviene esclusivamente dopo il
-- tocco esplicito dell'utente sul pulsante "Elimina" nell'app.

alter table public.messages
  add column if not exists pending_deletion_transaction_ids text[] not null default '{}';

comment on column public.messages.pending_deletion_transaction_ids is
  'Id delle transazioni candidate a eliminazione trovate da ai-chat. La Chat mostra '
  'una conferma esplicita e il client esegue il soft delete solo dopo il tocco utente.';
