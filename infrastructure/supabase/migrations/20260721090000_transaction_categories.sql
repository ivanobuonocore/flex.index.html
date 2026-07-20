-- Fase 3, slice 7C — "Bilancio con categorie" (docs/product/06-information-architecture.md,
-- richiesta esplicita dell'utente: una spesa come "barbiere" va classificata, non solo
-- registrata). Colonna aggiuntiva su una tabella esistente, non una nuova entità: stesso
-- pattern già usato per `workspaces.category` (Fase 3, slice 7A).

alter table public.transactions
  add column if not exists category text not null default 'altro'
    check (category in (
      'alimentari', 'trasporti', 'casa', 'bollette', 'salute',
      'svago', 'shopping', 'istruzione', 'stipendio', 'altro'
    ));

comment on column public.transactions.category is
  'Fase 3, slice 7C. Classificazione a colpo d''occhio del bilancio, non una tassonomia '
  'personalizzabile: set fisso, coerente con packages/domain TransactionCategory. Default '
  '''altro'' sia per le transazioni esistenti sia per quelle create prima che questa colonna '
  'esistesse.';
