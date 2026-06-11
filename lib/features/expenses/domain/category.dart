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
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    final rawSubcategories = map['subcategories'] as List<dynamic>? ?? const [];
    return ExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      subcategories: rawSubcategories
          .map((e) => Subcategory.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final String icon;
  final String color;
  final List<Subcategory> subcategories;
}
