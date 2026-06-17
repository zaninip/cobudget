-- category_learning: memoria per-budget delle scelte di categoria dell'utente.
--
-- Mappa "negoziante normalizzato" (merchant_key) -> categoria/sottocategoria, per
-- precompilare la categoria all'import delle spese da screenshot (stadio condiviso
-- tra il motore Free e quello Claude). Per-budget perche' le categorie sono gia'
-- per-budget e condivise tra i membri: la memoria ne beneficia tutto il budget.
--
-- Alimentata ad ogni salvataggio (import, modifica manuale, inserimento manuale)
-- con la categoria FINALE della voce, qualunque ne sia l'origine (anche un
-- suggerimento di Claude accettato). Last-write-wins via upsert sul vincolo unico.

create table if not exists public.category_learning (
  id uuid primary key default gen_random_uuid(),
  budget_id uuid not null references public.budgets (id) on delete cascade,
  merchant_key text not null,
  category_id uuid not null references public.categories (id) on delete cascade,
  subcategory_id uuid references public.subcategories (id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (budget_id, merchant_key)
);

create index if not exists idx_category_learning_budget
  on public.category_learning (budget_id);

alter table public.category_learning enable row level security;

-- Lettura/scrittura solo ai membri del budget (come per expenses, 0003).
-- Servono sia insert sia update perche' l'upsert e' insert-or-update.
create policy "members can read category_learning"
  on public.category_learning for select
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = category_learning.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can insert category_learning"
  on public.category_learning for insert
  with check (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = category_learning.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can update category_learning"
  on public.category_learning for update
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = category_learning.budget_id
        and budget_members.user_id = auth.uid()
    )
  );
