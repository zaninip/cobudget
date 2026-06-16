import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_controller.dart';

/// Modello Claude usato per l'estrazione delle spese da screenshot:
/// Standard = Sonnet (piu' economico), Performante = Opus (piu' accurato).
/// La scelta e' persistita localmente con SharedPreferences, come il tema.
enum ExtractionModel {
  standard,
  performante;

  /// Valore inviato alla Edge Function `extract-expenses` (campo `modelTier`).
  String get wireValue => name;

  static ExtractionModel fromName(String? value) =>
      value == 'performante' ? ExtractionModel.performante : ExtractionModel.standard;
}

class ExtractionModelController extends Notifier<ExtractionModel> {
  static const _key = 'extraction_model';

  @override
  ExtractionModel build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return ExtractionModel.fromName(stored);
  }

  Future<void> setModel(ExtractionModel model) async {
    state = model;
    await ref.read(sharedPreferencesProvider).setString(_key, model.name);
  }
}

final extractionModelControllerProvider =
    NotifierProvider<ExtractionModelController, ExtractionModel>(ExtractionModelController.new);
