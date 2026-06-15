import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Istanza di [SharedPreferences] inizializzata in `main.dart` e iniettata nel
/// [ProviderScope]. Va sovrascritta con `overrideWithValue` all'avvio.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider deve essere sovrascritto in main()');
});

/// Gestisce il tema scelto dall'utente (Sistema/Chiaro/Scuro) e lo persiste
/// localmente con SharedPreferences (vedi UI_DESIGN.md - sezione 9).
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
