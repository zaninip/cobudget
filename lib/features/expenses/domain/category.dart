/// Sottocategoria di spesa, figlia di una [ExpenseCategory] (vedi DATABASE_SCHEMA.md).
class Subcategory {
  const Subcategory({required this.id, required this.name});

  factory Subcategory.fromMap(Map<String, dynamic> map) {
    return Subcategory(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  final String id;
  final String name;
}

/// Categoria principale di spesa, globale (`budgetId == null`) o specifica di un budget.
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.subcategories,
    this.budgetId,
    this.overridesCategoryId,
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    final rawSubcategories = map['subcategories'] as List<dynamic>? ?? const [];
    return ExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      budgetId: map['budget_id'] as String?,
      overridesCategoryId: map['overrides_category_id'] as String?,
      subcategories: rawSubcategories
          .map((e) => Subcategory.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final String icon;
  final String color;

  /// `null` per le categorie predefinite/globali, valorizzato per quelle del budget.
  final String? budgetId;

  /// Se valorizzato, questa categoria del budget sostituisce (oscura) la categoria
  /// globale indicata: nasce dal "fork" di una predefinita modificata.
  final String? overridesCategoryId;

  /// Le globali (predefinite) non si modificano in place: la modifica crea una copia
  /// budget-specifica. Le altre si aggiornano direttamente.
  bool get isGlobal => budgetId == null;

  final List<Subcategory> subcategories;
}
