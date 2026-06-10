import 'package:supabase_flutter/supabase_flutter.dart';

/// Astrazione sull'autenticazione, basata su Supabase Auth (email/password).
abstract class AuthRepository {
  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
