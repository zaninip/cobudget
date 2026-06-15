-- Distingue uscite (spese) ed entrate sulle voci di expenses.
-- 'expense' = uscita (default, retrocompatibile con le righe esistenti),
-- 'income'  = entrata.

alter table public.expenses
  add column if not exists type text not null default 'expense'
  check (type in ('expense', 'income'));
