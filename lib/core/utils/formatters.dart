// Formattazione e parsing dei valori mostrati/inseriti dall'utente.

/// Formatta una data come "gg/MM/aaaa".
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// Converte il testo di un campo importo in numero, accettando la virgola
/// come separatore decimale. Restituisce `null` se il valore non è valido.
double? parseAmount(String value) => double.tryParse(value.trim().replaceAll(',', '.'));
