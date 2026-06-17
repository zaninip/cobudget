import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../app/extraction_model_controller.dart';
import '../../expenses/domain/category.dart';
import '../domain/extract_repository.dart';
import '../domain/extracted_expense.dart';
import 'ocr_expense_parser.dart';

/// Estrazione gratuita e on-device: OCR con Google ML Kit + parser euristico
/// ([parseOcrLines]). Nessuna chiave, nessun server. Disponibile solo su
/// smartphone (Android/iOS): ML Kit non ha un'implementazione web.
class MlKitExtractRepository implements ExtractRepository {
  @override
  Future<List<ExtractedExpense>> extract({
    required Uint8List bytes,
    required String mediaType,
    required List<ExpenseCategory> categories,
    required ExtractionModel model,
    String? sourcePath,
  }) async {
    if (kIsWeb) {
      throw Exception(
        'La lettura gratuita on-device e\' disponibile solo su smartphone, '
        'non nel browser. Apri l\'app dal telefono oppure usa l\'opzione '
        '"Claude based" nelle Impostazioni.',
      );
    }
    if (sourcePath == null || sourcePath.isEmpty) {
      throw Exception('Immagine non disponibile per la lettura on-device.');
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(sourcePath),
      );
      final lines = <OcrLine>[
        for (final block in recognized.blocks)
          for (final line in block.lines)
            OcrLine(line.text, line.boundingBox),
      ];
      return parseOcrLines(lines, currentYear: DateTime.now().year);
    } finally {
      await recognizer.close();
    }
  }
}
