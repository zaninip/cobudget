import 'dart:typed_data';

import '../../../app/extraction_model_controller.dart';
import '../../expenses/domain/category.dart';
import 'extracted_expense.dart';

/// Astrazione sull'estrazione delle spese da uno screenshot (ARCHITECTURE.md - flow 2).
/// Due implementazioni dietro la stessa interfaccia, scelte in base al motore
/// configurato in Impostazioni (vedi `extractRepositoryProvider`):
/// - percorso Claude Vision (Edge Function): usa [bytes]/[mediaType] e [model];
/// - percorso Free on-device (ML Kit, solo mobile): usa [sourcePath].
abstract class ExtractRepository {
  /// Restituisce le voci estratte dall'immagine. [categories] vengono passate per
  /// il suggerimento (solo Claude); [model] sceglie il tier (solo Claude);
  /// [sourcePath] e' il percorso del file su disco, usato dall'OCR on-device.
  Future<List<ExtractedExpense>> extract({
    required Uint8List bytes,
    required String mediaType,
    required List<ExpenseCategory> categories,
    required ExtractionModel model,
    String? sourcePath,
  });
}
