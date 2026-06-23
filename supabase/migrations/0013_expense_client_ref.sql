-- client_ref: identificatore di correlazione generato lato client durante un
-- insert in blocco delle spese (import da screenshot). Serve a riabbinare in modo
-- affidabile ogni riga inserita ai propri tag SENZA dipendere dall'ordine in cui
-- PostgREST restituisce le righe della `.select()` (vedi
-- SupabaseExpenseRepository.addExpenses): l'app genera un UUID per voce, lo invia
-- nell'insert e lo rilegge nella select, costruendo una mappa client_ref -> id.
--
-- Nullable: gli inserimenti singoli/manuali e le spese spalmate non lo valorizzano.
-- Non indicizzato di proposito: viene usato solo nella stessa transazione di insert,
-- mai per ricerche successive. Nessuna policy RLS aggiuntiva: la colonna eredita
-- quelle di `expenses` (0003).
alter table public.expenses
  add column if not exists client_ref uuid;
