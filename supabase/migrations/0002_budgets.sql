-- budgets: gruppo di spesa condiviso tra utenti (vedi DATABASE_SCHEMA.md)

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.budget_members (
  budget_id uuid not null references public.budgets (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (budget_id, user_id)
);

create index if not exists idx_members_user on public.budget_members (user_id);

alter table public.budgets enable row level security;
alter table public.budget_members enable row level security;

create policy "members can read budget"
  on public.budgets for select
  using (
    exists (
      select 1 from public.budget_members
      where budget_members.budget_id = budgets.id
        and budget_members.user_id = auth.uid()
    )
  );

create policy "users can read own memberships"
  on public.budget_members for select
  using (auth.uid() = user_id);

-- Genera un codice invito alfanumerico univoco di 6 caratteri
-- (esclude 0/O/1/I per evitare ambiguità visive).
create or replace function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  code_exists boolean;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(chars, floor(random() * length(chars))::int + 1, 1);
    end loop;

    select exists(select 1 from public.budgets where invite_code = code) into code_exists;
    exit when not code_exists;
  end loop;

  return code;
end;
$$;

-- Crea un nuovo budget e ne rende membro l'utente corrente.
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

  insert into public.budget_members (budget_id, user_id)
  values (new_budget.id, auth.uid());

  return new_budget;
end;
$$;

-- Aggiunge l'utente corrente a un budget esistente tramite codice invito.
create or replace function public.join_budget(p_invite_code text)
returns public.budgets
language plpgsql
security definer
set search_path = public
as $$
declare
  target_budget public.budgets;
begin
  select * into target_budget
  from public.budgets
  where invite_code = upper(p_invite_code);

  if not found then
    raise exception 'Codice invito non valido';
  end if;

  insert into public.budget_members (budget_id, user_id)
  values (target_budget.id, auth.uid())
  on conflict (budget_id, user_id) do nothing;

  return target_budget;
end;
$$;
