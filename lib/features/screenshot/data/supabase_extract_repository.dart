import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/extraction_model_controller.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../expenses/domain/category.dart';
import '../domain/extract_repository.dart';
import '../domain/extracted_expense.dart';

class SupabaseExtractRepository implements ExtractRepository {
  SupabaseExtractRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExtractedExpense>> extract({
    required Uint8List bytes,
    required String mediaType,
    required List<ExpenseCategory> categories,
    required ExtractionModel model,
  }) async {
    final res = await _client.functions.invoke(
      'extract-expenses',
      body: {
        'image': base64Encode(bytes),
        'mediaType': mediaType,
        'modelTier': model.wireValue,
        'categories': [
          for (final c in categories)
            {
              'id': c.id,
              'name': c.name,
              'subcategories': [
                for (final s in c.subcategories) {'id': s.id, 'name': s.name},
              ],
            },
        ],
      },
    );

    final data = res.data;
    final rawList = (data is Map ? data['expenses'] : null) as List<dynamic>? ?? const [];
    return rawList
        .map((e) => ExtractedExpense.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final extractRepositoryProvider = Provider<ExtractRepository>(
  (ref) => SupabaseExtractRepository(ref.watch(supabaseClientProvider)),
);
