-- Ruolo "admin" per i budget: chi crea un budget ne è amministratore e, a
-- differenza di un membro normale, può ELIMINARLO (non solo uscirne).
-- L'eliminazione del budget cancella in cascata tutto ciò che vi è collegato
-- (membri, categorie/sottocategorie, spese, memoria di categorizzazione), grazie
-- ai vincoli `on delete cascade` già presenti sulle FK verso budgets.

alter table public.budget_members
  add column if not exists role text not null default 'member'
  check (role in ('admin', 'member'));

-- create_budget: il creatore del budget diventa admin.
create or replace function public.create_budget(p_name text)
returns public.budgets
language plpgsql
security definer
set search_path = public
as $$
declare
  new_budget public.budgets;
begin
  insert into public.budgets (name, invite_code)
  values (p_name, public.generate_invite_code())
  returning * into new_budget;

  insert into public.budget_members (budget_id, user_id, role)
  values (new_budget.id, auth.uid(), 'admin');

  return new_budget;
end;
$$;

-- delete_budget: elimina definitivamente un budget. Solo un admin del budget può
-- farlo. SECURITY DEFINER per poter cancellare la riga di budgets (su cui non
-- esiste una policy di delete): la verifica del ruolo sostituisce la RLS.
create or replace function public.delete_budget(p_budget_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.budget_members
    where budget_members.budget_id = p_budget_id
      and budget_members.user_id = auth.uid()
      and budget_members.role = 'admin'
  ) then
    raise exception 'Solo un amministratore può eliminare questo budget';
  end if;

  delete from public.budgets where id = p_budget_id;
end;
$$;

-- Backfill per i budget già esistenti: rende admin il primo membro (per
-- joined_at), che è di fatto il creatore.
update public.budget_members bm
set role = 'admin'
from (
  select distinct on (budget_id) budget_id, user_id
  from public.budget_members
  order by budget_id, joined_at
) first
where bm.budget_id = first.budget_id
  and bm.user_id = first.user_id;
