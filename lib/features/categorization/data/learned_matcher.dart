import '../domain/category_learning_repository.dart';
import 'merchant_key.dart';

/// Cerca nella memoria [learned] (mappa `merchant_key` -> categoria) la categoria
/// appresa per [title]. Logica:
///  1. **match esatto** sulla chiave normalizzata;
///  2. **fallback a sottoinsieme**: una chiave appresa i cui token sono tutti
///     contenuti nei token del titolo letto (la chiave appresa e' il "nucleo" del
///     negoziante e il titolo ha parole in piu', es. appreso "monoprix" vs letto
///     "monoprix centre ville"). Sceglie la candidata piu' specifica (piu' token);
///     se a parita' di specificita' restano categorie diverse, rinuncia (ambiguo).
/// Restituisce null se non c'e' un match affidabile.
LearnedCategory? matchLearned(Map<String, LearnedCategory> learned, String title) {
  final key = merchantKey(title);
  if (key.isEmpty) return null;

  final exact = learned[key];
  if (exact != null) return exact;

  final itemTokens = key.split(' ').toSet();
  LearnedCategory? best;
  var bestLen = 0;
  var ambiguous = false;
  for (final entry in learned.entries) {
    final learnedTokens = entry.key.split(' ').where((t) => t.isNotEmpty).toSet();
    if (learnedTokens.isEmpty || !itemTokens.containsAll(learnedTokens)) continue;
    if (learnedTokens.length > bestLen) {
      bestLen = learnedTokens.length;
      best = entry.value;
      ambiguous = false;
    } else if (learnedTokens.length == bestLen && best != null && entry.value != best) {
      ambiguous = true;
    }
  }
  return ambiguous ? null : best;
}
