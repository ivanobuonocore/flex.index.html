-- Fase 3, "Sezioni fisse" (docs/product/06-information-architecture.md): ogni utente ha al
-- massimo un Workspace per ciascuna categoria di sistema (bilancio/appuntamenti/attivita/
-- documenti). Il bootstrap lato app (workspaceBootstrapProvider) è idempotente per singola
-- chiamata, ma due sessioni concorrenti (es. due tab aperte) potrebbero correre in parallelo:
-- questo indice unico parziale è l'unica garanzia reale contro i duplicati (Architectural
-- Principles, Principio 9 — la sicurezza/validazione non può dipendere solo dall'app).

-- Fix (bug segnalato dall'utente: "ci sono più categorie di appuntamenti"): questa migrazione
-- non era ancora stata applicata a un progetto Supabase reale quando è stata scritta — nel
-- frattempo il bootstrap ha potuto inserire più righe con la stessa categoria a ogni ricarica
-- dell'app, senza che nulla lo impedisse. Prima di creare l'indice, disattiva (soft delete) le
-- sezioni fisse duplicate: mantiene la più vecchia per ciascuna (owner_id, categoria) — la stessa
-- regola già applicata lato app in `workspacesProvider` — e archivia le altre. Idempotente:
-- eseguita di nuovo dopo che l'indice esiste già, non trova più duplicati (where deleted_at is
-- null) e non fa nulla.
with duplicates as (
  select id,
         row_number() over (
           partition by owner_id, category
           order by created_at asc
         ) as rn
  from public.workspaces
  where category in ('bilancio', 'appuntamenti', 'attivita', 'documenti')
    and deleted_at is null
)
update public.workspaces
set deleted_at = now(), status = 'archived'
where id in (select id from duplicates where rn > 1);

create unique index if not exists workspaces_owner_system_category_unique
  on public.workspaces (owner_id, category)
  where category in ('bilancio', 'appuntamenti', 'attivita', 'documenti')
    and deleted_at is null;
