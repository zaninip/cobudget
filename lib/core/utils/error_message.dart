import 'package:supabase_flutter/supabase_flutter.dart';

/// Messaggio leggibile da mostrare all'utente a partire da un errore.
/// Estrae il testo dalle eccezioni note di Supabase, altrimenti restituisce
/// un messaggio generico.
String errorMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Si è verificato un errore. Riprova.';
}
