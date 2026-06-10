import 'budget.dart';

/// Astrazione sulla gestione del budget condiviso (creazione/accesso tramite codice).
abstract class BudgetRepository {
  /// Il budget di cui l'utente corrente è membro, o `null` se non ne ha ancora uno.
  Future<Budget?> getCurrentBudget();

  Future<Budget> createBudget(String name);

  Future<Budget> joinBudget(String inviteCode);
}
