import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../domain/category_learning_repository.dart';
import 'merchant_key.dart';

class SupabaseCategoryLearningRepository implements CategoryLearningRepository {
  SupabaseCategoryLearningRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, LearnedCategory>> suggestions(String budgetId) async {
    final result = await _client
        .from('category_learning')
        .select('merchant_key, category_id, subcategory_id')
        .eq('budget_id', budgetId);

    return {
      for (final row in result as List)
        (row as Map)['merchant_key'] as String: (
          categoryId: row['category_id'] as String,
          subcategoryId: row['subcategory_id'] as String?,
        ),
    };
  }

  @override
  Future<void> recordChoices({
    required String budgetId,
    required List<LearnedEntry> entries,
  }) async {
    // Una sola riga per chiave (l'ultima vince), saltando le chiavi vuote.
    final rows = <String, Map<String, dynamic>>{};
    for (final e in entries) {
      final key = merchantKey(e.title);
      if (key.isEmpty) continue;
      rows[key] = {
        'budget_id': budgetId,
        'merchant_key': key,
        'category_id': e.categoryId,
        'subcategory_id': e.subcategoryId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
    }
    if (rows.isEmpty) return;

    await _client
        .from('category_learning')
        .upsert(rows.values.toList(), onConflict: 'budget_id,merchant_key');
  }
}

final categoryLearningRepositoryProvider = Provider<CategoryLearningRepository>(
  (ref) => SupabaseCategoryLearningRepository(ref.watch(supabaseClientProvider)),
);
