// Normalizzazione del titolo di una spesa in una "chiave negoziante" stabile,
// usata dalla memoria di categorizzazione (category_learning) sia in scrittura
// (chiave salvata) sia in lettura (match). Funzione pura e testabile: e' la parte
// euristica/iterativa dello stadio di categorizzazione, da affinare sui dati reali.
//
// Esempi:
//   "CB Station Carrefour du 10/05" -> "station carrefour"
//   "Virement de Paolo Zanini"      -> "paolo zanini"
//   "PAYPAL *NETFLIX"               -> "netflix"

// Parole-rumore rimosse: prefissi di pagamento e preposizioni che non
// identificano il negoziante. Conservativo di proposito (si puo' estendere).
const _noiseWords = <String>{
  'cb', 'carta', 'card', 'pagamento', 'paiement', 'payment', 'paypal', 'sumup',
  'pos', 'addebito', 'prelievo', 'bonifico', 'virement', 'reçu', 'recu', 'emis',
  'emise', 'de', 'du', 'del', 'di', 'da', 'the', 'a', 'al',
};

final _nonLetterRe = RegExp(r'[^a-z ]');
final _multiSpaceRe = RegExp(r'\s+');

/// Restituisce la chiave normalizzata del [title], o stringa vuota se dopo la
/// pulizia non resta nulla di significativo (in tal caso la voce non viene ne'
/// registrata ne' matchata). I token duplicati vengono rimossi (mantenendo
/// l'ordine di prima comparsa), cosi' "Monoprix MONOPRIX" -> "monoprix".
String merchantKey(String title) {
  var s = _stripAccents(title.toLowerCase());
  // Via cifre, date e qualsiasi cosa non sia una lettera o uno spazio.
  s = s.replaceAll(_nonLetterRe, ' ');
  final seen = <String>{};
  final tokens = <String>[];
  for (final t in s.split(_multiSpaceRe)) {
    if (t.isEmpty || _noiseWords.contains(t)) continue;
    if (seen.add(t)) tokens.add(t);
  }
  return tokens.join(' ');
}

String _stripAccents(String s) => s
    .replaceAll(RegExp('[àáâä]'), 'a')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[òóôö]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u')
    .replaceAll('ç', 'c');
