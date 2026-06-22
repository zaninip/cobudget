-- Flag "spesa straordinaria" sulle voci di expenses.
-- Identifica le spese eccezionali/fuori budget (es. acquisti una tantum) così da
-- poterle escludere dai grafici e dalla lista con un filtro dedicato.
-- Default false: retrocompatibile con le righe esistenti.

alter table public.expenses
  add column if not exists is_exceptional boolean not null default false;
