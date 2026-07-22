-- Notifica push su budget quasi superato (integrazione richiesta esplicitamente). Traccia
-- l'ultima soglia già notificata per non rimandare la stessa notifica a ogni transazione
-- confermata nello stesso mese: `last_alert_month` (YYYY-MM) fa "scadere" naturalmente lo stato a
-- ogni nuovo mese, senza bisogno di un job di reset separato.

alter table public.category_budgets
  add column if not exists last_alert_threshold integer,
  add column if not exists last_alert_month text;

comment on column public.category_budgets.last_alert_threshold is
  'Ultima soglia (80 o 100) per cui è già stata inviata una notifica push in last_alert_month — '
  'evita di notificare di nuovo la stessa soglia a ogni transazione confermata dello stesso mese. '
  'Scritta solo dalla Edge Function send-budget-alert, mai dal client.';

comment on column public.category_budgets.last_alert_month is
  'Mese (YYYY-MM) a cui si riferisce last_alert_threshold: un mese diverso da quello corrente '
  'equivale a "nessuna soglia ancora notificata questo mese", senza bisogno di un reset esplicito.';
