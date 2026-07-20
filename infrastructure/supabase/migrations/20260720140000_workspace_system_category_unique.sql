-- Fase 3, "Sezioni fisse" (docs/product/06-information-architecture.md): ogni utente ha al
-- massimo un Workspace per ciascuna categoria di sistema (bilancio/appuntamenti/attivita/
-- documenti). Il bootstrap lato app (workspaceBootstrapProvider) è idempotente per singola
-- chiamata, ma due sessioni concorrenti (es. due tab aperte) potrebbero correre in parallelo:
-- questo indice unico parziale è l'unica garanzia reale contro i duplicati (Architectural
-- Principles, Principio 9 — la sicurezza/validazione non può dipendere solo dall'app).
create unique index if not exists workspaces_owner_system_category_unique
  on public.workspaces (owner_id, category)
  where category in ('bilancio', 'appuntamenti', 'attivita', 'documenti')
    and deleted_at is null;
