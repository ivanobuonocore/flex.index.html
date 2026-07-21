-- Promemoria ricorrenti (richiesta esplicita dell'utente). Niente RRULE/logica nel
-- cron `send-due-reminders` (già configurato e funzionante, non va toccato): la
-- ricorrenza viene "espansa" in più righe indipendenti al momento della creazione
-- (ai-chat/index.ts), ciascuna con il proprio starts_at e lo stesso
-- recurrence_group_id — send-due-reminders continua a trattarle come eventi
-- indipendenti, esattamente come già fa oggi.

alter table public.calendar_events
  add column if not exists recurrence_group_id uuid;

create index if not exists calendar_events_recurrence_group_idx
  on public.calendar_events (recurrence_group_id)
  where recurrence_group_id is not null;

comment on column public.calendar_events.recurrence_group_id is
  'Accomuna le occorrenze generate da un unico promemoria ricorrente (create_reminder con '
  'recurrence != "none"). Null per un promemoria singolo. Solo informativo/di visualizzazione '
  'in questa slice: eliminare un''occorrenza elimina solo quella riga, non l''intera serie.';
