import 'category.dart';
import 'expense.dart';

/// Dati di una nuova voce da inserire in blocco (usato dall'import da screenshot).
typedef NewExpense = ({
  String title,
  double amount,
  DateTime date,
  String categoryId,
  String? subcategoryId,
  ExpenseType type,
});

/// Astrazione su categorie e spese di un budget (vedi ARCHITECTURE.md - flow 4).
abstract class ExpenseRepository {
  /// Categorie visibili per il budget (globali + specifiche del budget),
  /// ciascuna con le proprie sottocategorie.
  Future<List<ExpenseCategory>> getCategories(String budgetId);

  /// Tutte le spese del budget, ordinate per data decrescente.
  Future<List<Expense>> getRecentExpenses(String budgetId);

  /// Crea una singola voce (uscita o entrata) in data [date].
  Future<void> addExpense({
    required String budgetId,
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? subcategoryId,
    ExpenseType type = ExpenseType.expense,
  });

  /// Inserisce in blocco N voci nel budget [budgetId] con la `source` indicata
  /// (default `screenshot`), in un solo round-trip. Usato dalla review dell'import.
  Future<void> addExpenses({
    required String budgetId,
    required List<NewExpense> items,
    String source = 'screenshot',
  });

  /// Crea N voci (una per ogni mese tra [startMonth] e [endMonth] inclusi),
  /// con titoli "Titolo i/N" e lo stesso `spread_group_id`.
  Future<void> addSpreadExpenses({
    required String budgetId,
    required String title,
    required double amount,
    required DateTime startMonth,
    required DateTime endMonth,
    required String categoryId,
    String? subcategoryId,
    ExpenseType type = ExpenseType.expense,
  });

  /// Crea una nuova categoria specifica del budget [budgetId].
  Future<ExpenseCategory> createCategory({
    required String budgetId,
    required String name,
    required String icon,
    required String color,
  });

  /// Crea una nuova sottocategoria sotto [categoryId].
  Future<Subcategory> createSubcategory({
    required String categoryId,
    required String name,
  });

  /// Aggiorna titolo, importo, data, categoria e sottocategoria di una spesa esistente.
  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? subcategoryId,
  });

  /// Elimina una singola spesa.
  Future<void> deleteExpense(String id);

  /// Elimina tutte le spese con lo stesso [spreadGroupId] (spesa spalmata).
  Future<void> deleteSpreadGroup(String spreadGroupId);
}
