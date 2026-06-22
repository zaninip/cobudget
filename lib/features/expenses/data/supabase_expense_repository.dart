import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/supabase_provider.dart';
import '../domain/category.dart';
import '../domain/expense.dart';
import '../domain/expense_repository.dart';
import '../domain/tag.dart';

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
  Future<List<Tag>> getTags(String budgetId) async {
    final result = await _client
        .from('tags')
        .select('id, name')
        .eq('budget_id', budgetId)
        .order('name');

    return (result as List).map((e) => Tag.fromMap(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Expense>> getRecentExpenses(String budgetId) async {
    final result = await _client
        .from('expenses')
        .select('*, expense_tags(tag_id)')
        .eq('budget_id', budgetId)
        .order('date', ascending: false)
        .order('created_at', ascending: false);

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
    ExpenseType type = ExpenseType.expense,
    bool isExceptional = false,
    List<String> tagNames = const [],
  }) async {
    final inserted = await _client
        .from('expenses')
        .insert({
          'budget_id': budgetId,
          'user_id': _client.auth.currentUser!.id,
          'title': title,
          'amount': amount,
          'date': _formatDate(date),
          'category_id': categoryId,
          'subcategory_id': subcategoryId,
          'type': type.name,
          'is_exceptional': isExceptional,
        })
        .select('id')
        .single();
    await _attachTags(inserted['id'] as String, budgetId, tagNames);
  }

  @override
  Future<void> addExpenses({
    required String budgetId,
    required List<NewExpense> items,
    String source = 'screenshot',
  }) async {
    if (items.isEmpty) return;
    final userId = _client.auth.currentUser!.id;
    final rows = [
      for (final item in items)
        {
          'budget_id': budgetId,
          'user_id': userId,
          'title': item.title,
          'amount': item.amount,
          'date': _formatDate(item.date),
          'category_id': item.categoryId,
          'subcategory_id': item.subcategoryId,
          'type': item.type.name,
          'is_exceptional': item.isExceptional,
          'source': source,
        },
    ];
    // `.select('id')` restituisce gli id nello stesso ordine delle righe inviate,
    // così posso collegare i tag della voce corrispondente.
    final inserted = await _client.from('expenses').insert(rows).select('id');
    for (var i = 0; i < items.length; i++) {
      await _attachTags(
        (inserted[i] as Map)['id'] as String,
        budgetId,
        items[i].tagNames,
      );
    }
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
    ExpenseType type = ExpenseType.expense,
    bool isExceptional = false,
    List<String> tagNames = const [],
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
          'type': type.name,
          'is_exceptional': isExceptional,
        },
    ];

    // Gli stessi tag vengono applicati a tutte le rate della spesa spalmata.
    final inserted = await _client.from('expenses').insert(rows).select('id');
    if (tagNames.isNotEmpty) {
      final tagIds = await _resolveTagIds(budgetId, tagNames);
      if (tagIds.isNotEmpty) {
        await _client.from('expense_tags').insert([
          for (final row in inserted)
            for (final tagId in tagIds)
              {'expense_id': (row as Map)['id'] as String, 'tag_id': tagId},
        ]);
      }
    }
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

  @override
  Future<void> updateExpense({
    required String id,
    required String budgetId,
    required String title,
    required double amount,
    required DateTime date,
    required String categoryId,
    String? subcategoryId,
    bool isExceptional = false,
    List<String> tagNames = const [],
  }) async {
    await _client.from('expenses').update({
      'title': title,
      'amount': amount,
      'date': _formatDate(date),
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'is_exceptional': isExceptional,
    }).eq('id', id);
    // Le tag passate sostituiscono integralmente quelle precedenti.
    await _client.from('expense_tags').delete().eq('expense_id', id);
    await _attachTags(id, budgetId, tagNames);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  @override
  Future<void> deleteSpreadGroup(String spreadGroupId) async {
    await _client.from('expenses').delete().eq('spread_group_id', spreadGroupId);
  }

  /// Collega [tagNames] alla spesa [expenseId]: risolve i nomi in id (creando le
  /// tag mancanti) e inserisce le righe in `expense_tags`. No-op se non ci sono tag.
  Future<void> _attachTags(String expenseId, String budgetId, List<String> tagNames) async {
    final tagIds = await _resolveTagIds(budgetId, tagNames);
    if (tagIds.isEmpty) return;
    await _client.from('expense_tags').insert([
      for (final tagId in tagIds) {'expense_id': expenseId, 'tag_id': tagId},
    ]);
  }

  /// Risolve i nomi delle tag in id per il budget indicato, creando le tag non
  /// ancora esistenti. Normalizza con trim e deduplica case-insensitive (coerente
  /// con l'indice unico `(budget_id, lower(name))` della migrazione 0010).
  Future<List<String>> _resolveTagIds(String budgetId, List<String> tagNames) async {
    // Dedup case-insensitive mantenendo il primo nome (col suo casing) per i nuovi.
    final wanted = <String, String>{}; // lower(name) -> name
    for (final raw in tagNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      wanted.putIfAbsent(name.toLowerCase(), () => name);
    }
    if (wanted.isEmpty) return const [];

    final existing = await _client
        .from('tags')
        .select('id, name')
        .eq('budget_id', budgetId);
    final idByLower = {
      for (final row in existing as List)
        ((row as Map)['name'] as String).toLowerCase(): row['id'] as String,
    };

    final toCreate = [
      for (final entry in wanted.entries)
        if (!idByLower.containsKey(entry.key))
          {'budget_id': budgetId, 'name': entry.value},
    ];
    if (toCreate.isNotEmpty) {
      final created = await _client.from('tags').insert(toCreate).select('id, name');
      for (final row in created as List) {
        idByLower[((row as Map)['name'] as String).toLowerCase()] = row['id'] as String;
      }
    }

    return [
      for (final key in wanted.keys)
        if (idByLower[key] != null) idByLower[key]!,
    ];
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

/// Categorie e sottocategorie disponibili per il budget indicato.
final expenseCategoriesProvider = FutureProvider.family<List<ExpenseCategory>, String>(
  (ref, budgetId) => ref.watch(expenseRepositoryProvider).getCategories(budgetId),
);

/// Tag definite nel budget indicato (autocomplete nei form, filtri nei grafici).
final tagsProvider = FutureProvider.family<List<Tag>, String>(
  (ref, budgetId) => ref.watch(expenseRepositoryProvider).getTags(budgetId),
);

/// Le spese del budget indicato, ordinate per data decrescente.
final recentExpensesProvider = FutureProvider.family<List<Expense>, String>(
  (ref, budgetId) => ref.watch(expenseRepositoryProvider).getRecentExpenses(budgetId),
);
