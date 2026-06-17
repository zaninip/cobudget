import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/anthropic_key_controller.dart';
import '../../../app/extraction_engine_controller.dart';
import '../../../app/extraction_model_controller.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../expenses/domain/category.dart';
import '../domain/extract_repository.dart';
import '../domain/extracted_expense.dart';
import 'mlkit_extract_repository.dart';

class SupabaseExtractRepository implements ExtractRepository {
  SupabaseExtractRepository(this._client, this._keyController);

  final SupabaseClient _client;
  final AnthropicKeyController _keyController;

  @override
  Future<List<ExtractedExpense>> extract({
    required Uint8List bytes,
    required String mediaType,
    required List<ExpenseCategory> categories,
    required ExtractionModel model,
    String? sourcePath, // ignorato: il percorso Claude usa i bytes
  }) async {
    final userApiKey = await _keyController.readKey();

    final res = await _client.functions.invoke(
      'extract-expenses',
      body: {
        'image': base64Encode(bytes),
        'mediaType': mediaType,
        'modelTier': model.wireValue,
        if (userApiKey != null && userApiKey.isNotEmpty) 'apiKey': userApiKey,
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

final extractRepositoryProvider = Provider<ExtractRepository>((ref) {
  // Sceglie l'implementazione in base al motore configurato in Impostazioni.
  switch (ref.watch(extractionEngineControllerProvider)) {
    case ExtractionEngine.claude:
      final client = ref.watch(supabaseClientProvider);
      // Legge il notifier direttamente per accedere a readKey() senza bloccarsi
      // sull'AsyncValue (la lettura è lazy, avviene dentro extract()).
      final keyController = ref.watch(anthropicKeyControllerProvider.notifier);
      return SupabaseExtractRepository(client, keyController);
    case ExtractionEngine.free:
      return MlKitExtractRepository();
  }
});
