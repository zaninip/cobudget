import '../../../expenses/domain/expense.dart';
import '../../domain/extracted_expense.dart';

/// Risultato del dedup: voci da mostrare in review e numero di voci escluse.
typedef DedupResult = ({List<ExtractedExpense> kept, int excluded});

String _dateKey(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

bool _sameAmount(double a, double b) => (a - b).abs() < 0.005;

/// Esclude dalla review le voci gia' presenti, confrontando la coppia
/// `(data, importo)` (criterio scelto dall'utente). Esclude anche i doppioni
/// esatti interni allo stesso batch. Le voci **senza data** non si deduplicano
/// (manca il campo di confronto) e restano sempre in review.
DedupResult dedupExtracted(List<ExtractedExpense> extracted, List<Expense> existing) {
  final kept = <ExtractedExpense>[];
  final seenInBatch = <String>{};
  var excluded = 0;

  for (final e in extracted) {
    final date = e.date;
    if (date == null) {
      kept.add(e); // senza data non deduplicabile
      continue;
    }
    final dateKey = _dateKey(date);
    final batchKey = '$dateKey|${e.amount.toStringAsFixed(2)}';

    final inExisting =
        existing.any((x) => _dateKey(x.date) == dateKey && _sameAmount(x.amount, e.amount));

    if (inExisting || seenInBatch.contains(batchKey)) {
      excluded++;
      continue;
    }
    seenInBatch.add(batchKey);
    kept.add(e);
  }

  return (kept: kept, excluded: excluded);
}
