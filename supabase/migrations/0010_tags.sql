-- tags / expense_tags: etichette a testo libero sulle spese (relazione N-a-N).
--
-- Le tag sono una dimensione trasversale alle categorie (insiemi chiusi gestiti dal
-- budget): testo libero scelto dall'utente per raggruppare spese a piacere e filtrarle
-- nella pagina di riepilogo. Per-budget e condivise tra i membri, come le categorie.
--
-- `tags` e' il dizionario per-budget (alimenta autocomplete e filtri); `expense_tags`
-- collega le spese alle tag. RLS modellata sulle policy di expenses (0003) e
-- category_learning (0008): accesso ai soli membri del budget.

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  budget_id uuid not null references public.budgets (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

-- Unicita' case-insensitive: evita doppioni tipo "Vacanze" / "vacanze".
create unique index if not exists uq_tags_budget_name
  on public.tags (budget_id, lower(name));

create table if not exists public.expense_tags (
  expense_id uuid not null references public.expenses (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  primary key (expense_id, tag_id)
);

create index if not exists idx_expense_tags_tag on public.expense_tags (tag_id);

alter table public.tags enable row level security;
alter table public.expense_tags enable row level security;

-- tags: lettura/scrittura ai soli membri del budget.
create policy "members can read tags"
  on public.tags for select
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = tags.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can insert tags"
  on public.tags for insert
  with check (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = tags.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can update tags"
  on public.tags for update
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = tags.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can delete tags"
  on public.tags for delete
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = tags.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

-- expense_tags: la visibilita' eredita dal budget proprietario della spesa collegata.
create policy "members can read expense_tags"
  on public.expense_tags for select
  using (
    exists (
      select 1 from public.expenses
      join public.budget_members
        on budget_members.budget_id = expenses.budget_id
      where expenses.id = expense_tags.expense_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can insert expense_tags"
  on public.expense_tags for insert
  with check (
    exists (
      select 1 from public.expenses
      join public.budget_members
        on budget_members.budget_id = expenses.budget_id
      where expenses.id = expense_tags.expense_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can delete expense_tags"
  on public.expense_tags for delete
  using (
    exists (
      select 1 from public.expenses
      join public.budget_members
        on budget_members.budget_id = expenses.budget_id
      where expenses.id = expense_tags.expense_id
        and budget_members.user_id = auth.uid()
    )
  );
