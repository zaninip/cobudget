import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../budget/data/supabase_budget_repository.dart';
import '../domain/category.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';

class SupabaseExpenseRepository implements ExpenseRepository {
  SupabaseExpenseRepository(this._client);

  final SupabaseClient _client;
  static const _uuid = Uuid();

  @override
  Future<List<ExpenseCategory>> getCategories(String budgetId) async {
    final result = await _client
        .from('categories')
        .select('*, subcategories(*)')
        .or('budget_id.is.null,budget_id.eq.$budgetId')
        .order('created_at')
        .order('created_at', referencedTable: 'subcategories');

    return (result as List)
        .map((e) => ExpenseCategory.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Expense>> getRecentExpenses(String budgetId, {int limit = 10}) async {
    final result = await _client
        .from('expenses')
        .select()
        .eq('budget_id', budgetId)
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);

    return (result as List).map((e) => Expense.fromMap(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> addExpense({
    required String budgetId,
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? subcategoryId,
  }) async {
    await _client.from('expenses').insert({
      'budget_id': budgetId,
      'user_id': _client.auth.currentUser!.id,
      'title': title,
      'amount': amount,
      'date': _formatDate(date),
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
    });
  }

  @override
  Future<void> addSpreadExpenses({
    required String budgetId,
    required String title,
    required double amount,
    required DateTime startMonth,
    required DateTime endMonth,
    required String categoryId,
    String? subcategoryId,
  }) async {
    final months = <DateTime>[];
    var current = DateTime(startMonth.year, startMonth.month);
    final end = DateTime(endMonth.year, endMonth.month);
    while (!current.isAfter(end)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1);
    }

    final n = months.length;
    final spreadGroupId = _uuid.v4();
    final userId = _client.auth.currentUser!.id;
    final amountPerMonth = (amount / n * 100).round() / 100;

    final rows = [
      for (var i = 0; i < n; i++)
        {
          'budget_id': budgetId,
          'user_id': userId,
          'title': '$title ${i + 1}/$n',
          'amount': amountPerMonth,
          'date': _formatDate(months[i]),
          'category_id': categoryId,
          'subcategory_id': subcategoryId,
          'spread_group_id': spreadGroupId,
        },
    ];

    await _client.from('expenses').insert(rows);
  }

  @override
  Future<ExpenseCategory> createCategory({
    required String budgetId,
    required String name,
    required String icon,
    required String color,
  }) async {
    final result = await _client
        .from('categories')
        .insert({'budget_id': budgetId, 'name': name, 'icon': icon, 'color': color})
        .select()
        .single();

    return ExpenseCategory.fromMap({...result, 'subcategories': const []});
  }

  @override
  Future<Subcategory> createSubcategory({
    required String categoryId,
    required String name,
  }) async {
    final result = await _client
        .from('subcategories')
        .insert({'category_id': categoryId, 'name': name})
        .select()
        .single();

    return Subcategory.fromMap(result);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return SupabaseExpenseRepository(ref.watch(supabaseClientProvider));
});

/// Categorie e sottocategorie disponibili per il budget corrente.
final expenseCategoriesProvider = FutureProvider<List<ExpenseCategory>>((ref) async {
  final budget = await ref.watch(currentBudgetProvider.future);
  if (budget == null) return [];
  return ref.watch(expenseRepositoryProvider).getCategories(budget.id);
});

/// Le spese più recenti del budget corrente.
final recentExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final budget = await ref.watch(currentBudgetProvider.future);
  if (budget == null) return [];
  return ref.watch(expenseRepositoryProvider).getRecentExpenses(budget.id);
});
