-- Permette ai membri di un budget di creare nuove categorie/sottocategorie
-- dall'app (vedi ARCHITECTURE.md - flow 4, form di inserimento manuale).

-- categories: una nuova categoria creata da un utente è sempre legata
-- al proprio budget (mai globale, budget_id is null è riservato ai seed).
create policy "members can create budget categories"
  on public.categories for insert
  with check (
    budget_id is not null
    and exists (
      select 1 from public.budget_members
      where budget_members.budget_id = categories.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

-- subcategories: si può aggiungere una sottocategoria a qualsiasi categoria
-- visibile (globale o del proprio budget), stessa regola della select.
create policy "members can create subcategories for visible categories"
  on public.subcategories for insert
  with check (
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
