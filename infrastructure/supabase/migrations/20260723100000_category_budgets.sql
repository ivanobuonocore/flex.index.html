-- Budget per categoria (Domain Model, entità CategoryBudget — richiesta esplicita
-- dell'utente: "budget per categoria" nel Bilancio). Legato all'utente, non a un
-- Workspace: valutato contro lo stesso aggregato multi-Workspace già usato dal
-- Bilancio personale (tutti i Workspace personali, esclusi i Bilanci condivisi) — un
-- budget "per Workspace" non avrebbe un confronto naturale con quella vista.
create table if not exists public.category_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  category text not null check (category in (
    'alimentari', 'trasporti', 'casa', 'bollette', 'salute', 'svago',
    'shopping', 'istruzione', 'stipendio', 'altro'
  )),
  monthly_limit_cents integer not null,
  updated_at timestamptz not null default now(),
  constraint category_budgets_limit_positive check (monthly_limit_cents > 0),
  -- Al piu' un budget per categoria per utente: setBudget lato repository fa
  -- upsert su questo vincolo.
  constraint category_budgets_user_category_unique unique (user_id, category)
);

comment on table public.category_budgets is
  'Domain Model, entita'' CategoryBudget (docs/product/12-domain-model.md). Soglia '
  'mensile di spesa per categoria, legata all''utente.';

create index if not exists category_budgets_user_id_idx on public.category_budgets (user_id);

alter table public.category_budgets enable row level security;

create policy "category_budgets_select_own"
  on public.category_budgets for select
  using (user_id = auth.uid());

create policy "category_budgets_insert_own"
  on public.category_budgets for insert
  with check (user_id = auth.uid());

create policy "category_budgets_update_own"
  on public.category_budgets for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "category_budgets_delete_own"
  on public.category_budgets for delete
  using (user_id = auth.uid());

grant select, insert, update, delete on public.category_budgets to authenticated;
