-- Permette a un utente di uscire da un budget (vedi DATABASE_SCHEMA.md - budget_members)

create policy "users can leave budget"
  on public.budget_members for delete
  using (auth.uid() = user_id);
