import 'dart:typed_data';

import '../../../app/extraction_model_controller.dart';
import '../../expenses/domain/category.dart';
import 'extracted_expense.dart';

/// Astrazione sull'estrazione delle spese da uno screenshot (ARCHITECTURE.md - flow 2).
abstract class ExtractRepository {
  /// Invia l'immagine (in [bytes]) a Claude Vision tramite la Edge Function
  /// `extract-expenses` e restituisce le voci estratte. [categories] vengono
  /// passate per il suggerimento; [model] sceglie il tier (standard/performante).
  Future<List<ExtractedExpense>> extract({
    required Uint8List bytes,
    required String mediaType,
    required List<ExpenseCategory> categories,
    required ExtractionModel model,
  });
}
