import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_auth_repository.dart';

/// Stato dell'autenticazione: un eventuale messaggio informativo da mostrare
/// all'utente (es. conferma email in attesa). `null` = nessun messaggio.
class AuthController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(email: email, password: password);
      return null;
    });
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await ref
          .read(authRepositoryProvider)
          .signUpWithPassword(email: email, password: password);
      return response.session == null
          ? 'Controlla la tua email per confermare la registrazione.'
          : null;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, String?>(AuthController.new);
