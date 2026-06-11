-- categories/subcategories/expenses (vedi DATABASE_SCHEMA.md)

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  budget_id uuid references public.budgets (id) on delete cascade,
  name text not null,
  icon text not null,
  color text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  budget_id uuid not null references public.budgets (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  amount numeric(12, 2) not null,
  date date not null,
  category_id uuid not null references public.categories (id),
  subcategory_id uuid references public.subcategories (id),
  source text not null default 'manual' check (source in ('manual', 'screenshot')),
  spread_group_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists idx_expenses_budget_date on public.expenses (budget_id, date desc);
create index if not exists idx_expenses_category on public.expenses (category_id);
create index if not exists idx_expenses_spread on public.expenses (spread_group_id) where spread_group_id is not null;

alter table public.categories enable row level security;
alter table public.subcategories enable row level security;
alter table public.expenses enable row level security;

-- categories: globali (budget_id null) o del proprio budget
create policy "read global or own budget categories"
  on public.categories for select
  using (
    budget_id is null
    or exists (
      select 1 from public.budget_members
      where budget_members.budget_id = categories.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

-- subcategories: ereditano la visibilità dalla categoria padre
create policy "read subcategories of visible categories"
  on public.subcategories for select
  using (
    exists (
      select 1 from public.categories
      where categories.id = subcategories.category_id
        and (
          categories.budget_id is null
          or exists (
            select 1 from public.budget_members
            where budget_members.budget_id = categories.budget_id
              and budget_members.user_id = auth.uid()
          )
        )
    )
  );

-- expenses: lettura/scrittura solo per i membri del budget
create policy "members can read expenses"
  on public.expenses for select
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = expenses.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can insert expenses"
  on public.expenses for insert
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.budget_members
      where budget_members.budget_id = expenses.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can update expenses"
  on public.expenses for update
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = expenses.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "members can delete expenses"
  on public.expenses for delete
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = expenses.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

-- Categorie globali di default
insert into public.categories (budget_id, name, icon, color) values
  (null, 'Alimentari', 'shopping_cart', '#7C3AED'),
  (null, 'Trasporti', 'directions_car', '#2563EB'),
  (null, 'Casa', 'home', '#16A34A'),
  (null, 'Salute', 'favorite', '#DC2626'),
  (null, 'Tempo libero', 'sports_esports', '#F59E0B'),
  (null, 'Altro', 'category', '#6B7280');

-- Sottocategorie di default
with cat as (
  select id, name from public.categories where budget_id is null
)
insert into public.subcategories (category_id, name)
select cat.id, sub.name
from cat
join (
  values
    ('Alimentari', 'Supermercato'),
    ('Alimentari', 'Bar'),
    ('Alimentari', 'Ristorante'),
    ('Trasporti', 'Carburante'),
    ('Trasporti', 'Mezzi pubblici'),
    ('Trasporti', 'Manutenzione'),
    ('Casa', 'Affitto/Mutuo'),
    ('Casa', 'Bollette'),
    ('Casa', 'Manutenzione'),
    ('Salute', 'Farmacia'),
    ('Salute', 'Visite mediche'),
    ('Tempo libero', 'Cinema/Eventi'),
    ('Tempo libero', 'Abbonamenti'),
    ('Altro', 'Varie')
) as sub (category_name, name)
  on cat.name = sub.category_name;
