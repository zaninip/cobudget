import 'package:supabase_flutter/supabase_flutter.dart';

/// Messaggio leggibile da mostrare all'utente a partire da un errore.
/// Estrae il testo dalle eccezioni note di Supabase, altrimenti restituisce
/// un messaggio generico.
String errorMessage(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  if (error is FunctionException) {
    final details = error.details;
    if (details is Map && details['error'] != null) return details['error'].toString();
    return 'Errore nella funzione di estrazione (codice ${error.status}).';
  }
  return 'Si è verificato un errore. Riprova.';
}
