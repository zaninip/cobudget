-- Modifica di una categoria esistente (icona/nome/colore) senza danni alle spese.
--
-- Le spese puntano alla categoria solo via category_id: cambiare i campi della
-- categoria si riflette automaticamente su tutte le spese collegate.
--
-- Due casi:
--  * categoria del proprio budget (budget_id not null) -> UPDATE diretto (policy sotto);
--  * categoria predefinita/globale (budget_id is null, condivisa tra tutti i budget)
--    -> NON si modifica in place (cambierebbe per tutti): si crea una copia legata
--    al budget (fork_category) e si ri-agganciano spese e memoria di categorizzazione
--    di QUEL budget alla copia. La copia "oscura" la globale via overrides_category_id.

-- Riferimento alla categoria globale che una copia budget-specifica sostituisce.
alter table public.categories
  add column if not exists overrides_category_id uuid
    references public.categories (id) on delete set null;

-- Un budget non puo' avere due copie della stessa categoria globale.
create unique index if not exists idx_categories_budget_override
  on public.categories (budget_id, overrides_category_id)
  where overrides_category_id is not null;

-- I membri possono modificare le categorie del PROPRIO budget (mai le globali).
create policy "members can update budget categories"
  on public.categories for update
  using (
    budget_id is not null
    and exists (
      select 1 from public.budget_members
      where budget_members.budget_id = categories.budget_id
        and budget_members.user_id = auth.uid()
    )
  )
  with check (
    budget_id is not null
    and exists (
      select 1 from public.budget_members
      where budget_members.budget_id = categories.budget_id
        and budget_members.user_id = auth.uid()
    )
  );

-- fork_category: crea (o aggiorna, se gia' esiste) la copia budget-specifica di una
-- categoria globale con i campi modificati, clona le sottocategorie e ri-aggancia
-- spese e category_learning di p_budget_id alla copia. Atomica. Ritorna l'id copia.
create or replace function public.fork_category(
  p_budget_id uuid,
  p_category_id uuid,
  p_name text,
  p_icon text,
  p_color text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_category_id uuid;
  v_sub record;
  v_new_sub_id uuid;
begin
  -- Autorizzazione: solo i membri del budget di destinazione.
  if not exists (
    select 1 from public.budget_members
    where budget_id = p_budget_id and user_id = auth.uid()
  ) then
    raise exception 'not a member of budget %', p_budget_id;
  end if;

  -- La sorgente deve essere una categoria globale.
  if not exists (
    select 1 from public.categories
    where id = p_category_id and budget_id is null
  ) then
    raise exception 'category % is not a global category', p_category_id;
  end if;

  -- Se una copia esiste gia' (doppio fork), aggiornala in place e basta.
  select id into v_new_category_id
  from public.categories
  where budget_id = p_budget_id and overrides_category_id = p_category_id;

  if found then
    update public.categories
      set name = p_name, icon = p_icon, color = p_color
      where id = v_new_category_id;
    return v_new_category_id;
  end if;

  -- 1. Crea la copia budget-specifica con i campi modificati.
  insert into public.categories (budget_id, name, icon, color, overrides_category_id)
  values (p_budget_id, p_name, p_icon, p_color, p_category_id)
  returning id into v_new_category_id;

  -- 2. Clona le sottocategorie e ri-aggancia le righe del budget alla copia.
  for v_sub in
    select id, name from public.subcategories where category_id = p_category_id
  loop
    insert into public.subcategories (category_id, name)
    values (v_new_category_id, v_sub.name)
    returning id into v_new_sub_id;

    update public.expenses
      set subcategory_id = v_new_sub_id
      where budget_id = p_budget_id
        and category_id = p_category_id
        and subcategory_id = v_sub.id;

    update public.category_learning
      set subcategory_id = v_new_sub_id
      where budget_id = p_budget_id
        and category_id = p_category_id
        and subcategory_id = v_sub.id;
  end loop;

  -- 3. Ri-aggancia category_id (spese + memoria) del budget alla copia.
  update public.expenses
    set category_id = v_new_category_id
    where budget_id = p_budget_id and category_id = p_category_id;

  update public.category_learning
    set category_id = v_new_category_id
    where budget_id = p_budget_id and category_id = p_category_id;

  return v_new_category_id;
end;
$$;

grant execute on function public.fork_category(uuid, uuid, text, text, text) to authenticated;
