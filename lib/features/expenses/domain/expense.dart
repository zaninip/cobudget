/// Una spesa salvata nel budget (vedi DATABASE_SCHEMA.md).
class Expense {
  const Expense({
    required this.id,
    required this.budgetId,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.subcategoryId,
    this.spreadGroupId,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      budgetId: map['budget_id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      categoryId: map['category_id'] as String,
      subcategoryId: map['subcategory_id'] as String?,
      spreadGroupId: map['spread_group_id'] as String?,
    );
  }

  final String id;
  final String budgetId;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final String? subcategoryId;
  final String? spreadGroupId;
}
