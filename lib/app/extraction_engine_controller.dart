import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_controller.dart';

/// Motore usato per leggere le spese dagli screenshot:
/// - [free]: OCR on-device con Google ML Kit + parsing euristico. Gratis, senza
///   chiavi, ma disponibile solo su smartphone (Android/iOS), non sul web.
/// - [claude]: estrazione via Claude Vision (Edge Function). Richiede la chiave
///   Anthropic personale e consente di scegliere il modello.
/// La scelta e' persistita localmente con SharedPreferences, come il tema.
enum ExtractionEngine {
  free,
  claude;

  static ExtractionEngine fromName(String? value) =>
      value == 'claude' ? ExtractionEngine.claude : ExtractionEngine.free;
}

class ExtractionEngineController extends Notifier<ExtractionEngine> {
  static const _key = 'extraction_engine';

  @override
  ExtractionEngine build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return ExtractionEngine.fromName(stored);
  }

  Future<void> setEngine(ExtractionEngine engine) async {
    state = engine;
    await ref.read(sharedPreferencesProvider).setString(_key, engine.name);
  }
}

final extractionEngineControllerProvider =
    NotifierProvider<ExtractionEngineController, ExtractionEngine>(
  ExtractionEngineController.new,
);
