import 'budget.dart';

/// Astrazione sulla gestione dei budget condivisi (creazione/accesso tramite codice).
abstract class BudgetRepository {
  /// Tutti i budget di cui l'utente corrente è membro.
  Future<List<Budget>> getUserBudgets();

  /// Il budget con l'id indicato (l'utente deve esserne membro).
  Future<Budget> getBudgetById(String budgetId);

  Future<Budget> createBudget(String name);

  Future<Budget> joinBudget(String inviteCode);

  /// Rimuove l'utente corrente dai membri del budget.
  Future<void> leaveBudget(String budgetId);
}
