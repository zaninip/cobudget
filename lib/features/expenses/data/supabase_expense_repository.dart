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

    final categories = (result as List)
        .map((e) => ExpenseCategory.fromMap(e as Map<String, dynamic>))
        .toList();

    // Una globale "forkata" dal budget viene oscurata dalla sua copia budget-specifica:
    // mostriamo solo la copia, non il duplicato globale.
    final overridden = categories
        .map((c) => c.overridesCategoryId)
        .whereType<String>()
        .toSet();
    return categories.where((c) => !overridden.contains(c.id)).toList();
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
    // Un identificatore di correlazione per ogni voce: lo rispedisce il DB nella
    // select, così riabbino i tag alla riga giusta tramite client_ref invece che
    // per posizione (l'ordine di ritorno di PostgREST non è garantito).
    final refs = [for (final _ in items) _uuid.v4()];
    final rows = [
      for (var i = 0; i < items.length; i++)
        {
          'budget_id': budgetId,
          'user_id': userId,
          'title': items[i].title,
          'amount': items[i].amount,
          'date': _formatDate(items[i].date),
          'category_id': items[i].categoryId,
          'subcategory_id': items[i].subcategoryId,
          'type': items[i].type.name,
          'is_exceptional': items[i].isExceptional,
          'source': source,
          'client_ref': refs[i],
        },
    ];
    final inserted =
        await _client.from('expenses').insert(rows).select('id, client_ref');
    // Mappa client_ref -> id reale: riabbinamento esplicito, indipendente dall'ordine.
    final idByRef = {
      for (final row in inserted as List)
        (row as Map)['client_ref'] as String: row['id'] as String,
    };

    // Risolvo l'unione di tutti i nomi una sola volta (no N+1) e inserisco le
    // righe di expense_tags di tutte le voci in un'unica chiamata.
    final idByLower = await _resolveTagIdMap(
      budgetId,
      [for (final item in items) ...item.tagNames],
    );
    final tagRows = <Map<String, dynamic>>[
      for (var i = 0; i < items.length; i++)
        for (final tagId in _tagIdsFor(items[i].tagNames, idByLower))
          {'expense_id': idByRef[refs[i]]!, 'tag_id': tagId},
    ];
    if (tagRows.isNotEmpty) {
      await _client.from('expense_tags').insert(tagRows);
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
    final idByLower = await _resolveTagIdMap(budgetId, tagNames);
    final tagIds = _tagIdsFor(tagNames, idByLower);
    if (tagIds.isNotEmpty) {
      await _client.from('expense_tags').insert([
        for (final row in inserted)
          for (final tagId in tagIds)
            {'expense_id': (row as Map)['id'] as String, 'tag_id': tagId},
      ]);
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
  Future<void> updateCategory({
    required String budgetId,
    required ExpenseCategory category,
    required String name,
    required String icon,
    required String color,
  }) async {
    if (category.isGlobal) {
      // Predefinita: fork in una copia legata al budget (atomico, lato Postgres).
      await _client.rpc('fork_category', params: {
        'p_budget_id': budgetId,
        'p_category_id': category.id,
        'p_name': name,
        'p_icon': icon,
        'p_color': color,
      });
    } else {
      await _client
          .from('categories')
          .update({'name': name, 'icon': icon, 'color': color})
          .eq('id', category.id);
    }
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
    final idByLower = await _resolveTagIdMap(budgetId, tagNames);
    final tagIds = _tagIdsFor(tagNames, idByLower);
    if (tagIds.isEmpty) return;
    await _client.from('expense_tags').insert([
      for (final tagId in tagIds) {'expense_id': expenseId, 'tag_id': tagId},
    ]);
  }

  /// Risolve l'insieme di [tagNames] in una mappa `lower(name) -> id` per il
  /// budget indicato, creando le tag non ancora esistenti. Normalizza con trim e
  /// deduplica case-insensitive (coerente con l'indice unico `(budget_id, lower(name))`
  /// della migrazione 0010). Una sola lettura e al più un solo insert per l'intero
  /// insieme: chiamarla una volta evita le query N+1 sui batch.
  Future<Map<String, String>> _resolveTagIdMap(
    String budgetId,
    Iterable<String> tagNames,
  ) async {
    // Dedup case-insensitive mantenendo il primo nome (col suo casing) per i nuovi.
    final wanted = <String, String>{}; // lower(name) -> name
    for (final raw in tagNames) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      wanted.putIfAbsent(name.toLowerCase(), () => name);
    }
    if (wanted.isEmpty) return const {};

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

    return idByLower;
  }

  /// Traduce i nomi di tag di una singola voce negli id corrispondenti usando la
  /// mappa di [_resolveTagIdMap]. Mantiene l'ordine e deduplica (coerente con la
  /// dedup case-insensitive a monte).
  List<String> _tagIdsFor(List<String> tagNames, Map<String, String> idByLower) {
    final ids = <String>[];
    final seen = <String>{};
    for (final raw in tagNames) {
      final id = idByLower[raw.trim().toLowerCase()];
      if (id != null && seen.add(id)) ids.add(id);
    }
    return ids;
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
