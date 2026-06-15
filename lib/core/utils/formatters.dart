// Formattazione e parsing dei valori mostrati/inseriti dall'utente.

import 'package:intl/intl.dart';

/// Formatta una data come "gg/MM/aaaa".
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

final _amountFormat = NumberFormat('#,##0.00', 'it_IT');

/// Formatta un importo in euro all'italiana, es. "€ 1.240,50".
String formatCurrency(double amount) => '€ ${_amountFormat.format(amount)}';

/// Converte il testo di un campo importo in numero, accettando la virgola
/// come separatore decimale. Restituisce `null` se il valore non è valido.
double? parseAmount(String value) => double.tryParse(value.trim().replaceAll(',', '.'));
