-- get_budget_members: elenca i membri di un budget con il loro nome visualizzato.
--
-- La policy RLS su budget_members ("users can read own memberships") fa vedere a
-- ogni utente solo le proprie righe, quindi non si possono leggere gli altri
-- membri direttamente. Questa funzione SECURITY DEFINER aggira la RLS in modo
-- sicuro: verifica prima che l'utente corrente sia membro del budget richiesto,
-- poi restituisce l'elenco completo (vedi UI_DESIGN.md - sezione 9).

create or replace function public.get_budget_members(p_budget_id uuid)
returns table (
  user_id uuid,
  name text,
  joined_at timestamptz,
  is_self boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  -- L'utente corrente deve essere membro del budget per vederne i membri.
  if not exists (
    select 1 from public.budget_members
    where budget_members.budget_id = p_budget_id
      and budget_members.user_id = auth.uid()
  ) then
    raise exception 'Non sei membro di questo budget';
  end if;

  return query
  select
    bm.user_id,
    coalesce(p.display_name, split_part(u.email, '@', 1)) as name,
    bm.joined_at,
    bm.user_id = auth.uid() as is_self
  from public.budget_members bm
  left join public.profiles p on p.id = bm.user_id
  left join auth.users u on u.id = bm.user_id
  where bm.budget_id = p_budget_id
  order by bm.joined_at;
end;
$$;
