/// Categoria/sottocategoria apprese per un negoziante.
typedef LearnedCategory = ({String categoryId, String? subcategoryId});

/// Voce da registrare nella memoria: titolo grezzo (verra' normalizzato in
/// `merchantKey`) + categoria finale scelta dall'utente.
typedef LearnedEntry = ({String title, String categoryId, String? subcategoryId});

/// Memoria per-budget delle scelte di categoria (vedi 0008_category_learning.sql).
/// Stadio di categorizzazione condiviso tra il motore Free e quello Claude.
abstract class CategoryLearningRepository {
  /// Suggerimenti appresi per il budget, indicizzati per `merchant_key`.
  Future<Map<String, LearnedCategory>> suggestions(String budgetId);

  /// Registra (upsert) le scelte di categoria per il budget. Best-effort: non
  /// deve mai far fallire il salvataggio della spesa che la origina.
  Future<void> recordChoices({
    required String budgetId,
    required List<LearnedEntry> entries,
  });
}
