// Aggregazioni puramente client-side per la pagina di riepilogo del budget.
//
// Tutte le funzioni sono pure (nessuna dipendenza da Flutter/Supabase): partono
// dalla lista di [Expense] già caricata da `recentExpensesProvider` e producono
// i dati per i grafici. Sono facilmente testabili (vedi test/expense_summary_test.dart).

import '../../domain/category.dart';
import '../../domain/expense.dart';

/// Preset di periodo selezionabili nella barra filtri.
enum SummaryPeriod {
  thisMonth('Questo mese'),
  last3Months('Ultimi 3 mesi'),
  last6Months('Ultimi 6 mesi'),
  thisYear('Quest\'anno'),
  all('Tutto'),
  custom('Periodo personalizzato');

  const SummaryPeriod(this.label);

  final String label;
}

/// Granularità dei bucket temporali nella scheda "Andamento".
enum TrendGranularity { week, month }

/// Granularità di default in base al periodo: settimane per periodi brevi,
/// mesi per quelli lunghi. Resta comunque cambiabile a mano dall'utente.
TrendGranularity defaultGranularityFor(SummaryPeriod period) {
  switch (period) {
    case SummaryPeriod.thisMonth:
    case SummaryPeriod.last3Months:
      return TrendGranularity.week;
    case SummaryPeriod.last6Months:
    case SummaryPeriod.thisYear:
    case SummaryPeriod.all:
    case SummaryPeriod.custom:
      return TrendGranularity.month;
  }
}

/// Intervallo `[start, endExclusive)` di un periodo. `null` = nessun limite.
class DateRange {
  const DateRange(this.start, this.endExclusive);

  final DateTime? start;
  final DateTime? endExclusive;

  bool contains(DateTime d) =>
      (start == null || !d.isBefore(start!)) &&
      (endExclusive == null || d.isBefore(endExclusive!));
}

/// Calcola l'intervallo di date coperto da [period] rispetto a [now].
/// I periodi a finestra (3/6 mesi, anno) arrivano fino alla fine del mese corrente.
/// Per [SummaryPeriod.custom] usa [customStart]/[customEnd] (estremi inclusivi).
DateRange periodRange(
  SummaryPeriod period,
  DateTime now, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final nextMonth = DateTime(now.year, now.month + 1);
  switch (period) {
    case SummaryPeriod.thisMonth:
      return DateRange(DateTime(now.year, now.month), nextMonth);
    case SummaryPeriod.last3Months:
      return DateRange(DateTime(now.year, now.month - 2), nextMonth);
    case SummaryPeriod.last6Months:
      return DateRange(DateTime(now.year, now.month - 5), nextMonth);
    case SummaryPeriod.thisYear:
      return DateRange(DateTime(now.year), nextMonth);
    case SummaryPeriod.all:
      return const DateRange(null, null);
    case SummaryPeriod.custom:
      final start = customStart == null
          ? null
          : DateTime(customStart.year, customStart.month, customStart.day);
      final endExclusive = customEnd == null
          ? null
          : DateTime(customEnd.year, customEnd.month, customEnd.day + 1);
      return DateRange(start, endExclusive);
  }
}

/// Filtra le voci per periodo, categorie e sottocategorie selezionate.
/// Set vuoti = nessun vincolo su quella dimensione (tutte).
List<Expense> filterExpenses(
  List<Expense> expenses, {
  required SummaryPeriod period,
  Set<String> categoryIds = const {},
  Set<String> subcategoryIds = const {},
  DateTime? customStart,
  DateTime? customEnd,
  DateTime? now,
}) {
  final range = periodRange(
    period,
    now ?? DateTime.now(),
    customStart: customStart,
    customEnd: customEnd,
  );
  return [
    for (final e in expenses)
      if (range.contains(e.date) &&
          (categoryIds.isEmpty || categoryIds.contains(e.categoryId)) &&
          (subcategoryIds.isEmpty ||
              (e.subcategoryId != null && subcategoryIds.contains(e.subcategoryId))))
        e,
  ];
}

/// Totali aggregati di uscite ed entrate su un insieme di voci.
class Totals {
  const Totals({required this.outcome, required this.income});

  final double outcome;
  final double income;

  double get balance => income - outcome;

  bool get isEmpty => outcome == 0 && income == 0;
}

Totals computeTotals(List<Expense> expenses) {
  var outcome = 0.0;
  var income = 0.0;
  for (final e in expenses) {
    if (e.isIncome) {
      income += e.amount;
    } else {
      outcome += e.amount;
    }
  }
  return Totals(outcome: outcome, income: income);
}

/// Una "fetta" della ripartizione: una categoria (o sottocategoria) con il suo
/// importo. [colorHex] è `null` per il gruppo neutro ("Senza categoria"/resto).
class CategorySlice {
  const CategorySlice({
    required this.key,
    required this.label,
    required this.amount,
    this.colorHex,
  });

  /// id categoria/sottocategoria, oppure '' per il gruppo "senza".
  final String key;
  final String label;
  final double amount;
  final String? colorHex;

  double percentOf(double total) => total == 0 ? 0 : amount / total * 100;
}

/// Ripartizione degli importi per categoria (o per sottocategoria, se
/// [categoryId] è valorizzato) limitata al tipo [type], ordinata dal più grande.
List<CategorySlice> breakdownByCategory(
  List<Expense> expenses, {
  required List<ExpenseCategory> categories,
  required ExpenseType type,
  String? categoryId,
}) {
  final bySubcategory = categoryId != null;
  final categoryById = {for (final c in categories) c.id: c};

  // Mappa id -> nome/colore per la dimensione scelta.
  final names = <String, String>{};
  final colors = <String, String>{};
  if (bySubcategory) {
    final parent = categoryById[categoryId];
    for (final s in parent?.subcategories ?? const []) {
      names[s.id] = s.name;
      if (parent != null) colors[s.id] = parent.color;
    }
  } else {
    for (final c in categories) {
      names[c.id] = c.name;
      colors[c.id] = c.color;
    }
  }

  final totals = <String, double>{};
  for (final e in expenses) {
    if (e.type != type) continue;
    final key = bySubcategory ? (e.subcategoryId ?? '') : e.categoryId;
    totals[key] = (totals[key] ?? 0) + e.amount;
  }

  final slices = [
    for (final entry in totals.entries)
      CategorySlice(
        key: entry.key,
        label: entry.key.isEmpty
            ? (bySubcategory ? 'Senza sottocategoria' : 'Senza categoria')
            : names[entry.key] ?? (bySubcategory ? 'Senza sottocategoria' : 'Senza categoria'),
        amount: entry.value,
        colorHex: colors[entry.key],
      ),
  ];

  slices.sort((a, b) => b.amount.compareTo(a.amount));
  return slices;
}

/// Un bucket temporale (mese o settimana) con i suoi totali.
class PeriodBucket {
  const PeriodBucket({
    required this.start,
    required this.label,
    required this.outcome,
    required this.income,
  });

  final DateTime start;
  final String label;
  final double outcome;
  final double income;

  double get balance => income - outcome;

  bool get isEmpty => outcome == 0 && income == 0;
}

const _monthAbbr = [
  'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
  'lug', 'ago', 'set', 'ott', 'nov', 'dic',
];

DateTime _isoMonday(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime _bucketStartOf(DateTime d, TrendGranularity g) =>
    g == TrendGranularity.month ? DateTime(d.year, d.month) : _isoMonday(d);

DateTime _nextBucket(DateTime b, TrendGranularity g) => g == TrendGranularity.month
    ? DateTime(b.year, b.month + 1)
    : DateTime(b.year, b.month, b.day + 7);

String _bucketLabel(DateTime b, TrendGranularity g, bool multiYear) {
  if (g == TrendGranularity.week) {
    final d = b.day.toString().padLeft(2, '0');
    final m = b.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
  final abbr = _monthAbbr[b.month - 1];
  return multiYear ? '$abbr ${(b.year % 100).toString().padLeft(2, '0')}' : abbr;
}

/// Raggruppa le voci in bucket temporali contigui (anche vuoti) coprendo il
/// periodo selezionato, sommando uscite ed entrate per ciascun bucket.
List<PeriodBucket> bucketByTime(
  List<Expense> expenses, {
  required SummaryPeriod period,
  required TrendGranularity granularity,
  DateTime? customStart,
  DateTime? customEnd,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final range = periodRange(
    period,
    current,
    customStart: customStart,
    customEnd: customEnd,
  );
  final filtered = [for (final e in expenses) if (range.contains(e.date)) e];

  // Accumula gli importi sull'inizio del bucket di appartenenza.
  final acc = <DateTime, List<double>>{};
  for (final e in filtered) {
    final b = _bucketStartOf(e.date, granularity);
    final a = acc.putIfAbsent(b, () => [0, 0]);
    if (e.isIncome) {
      a[1] += e.amount;
    } else {
      a[0] += e.amount;
    }
  }

  // Estremi della timeline: dal periodo se delimitato, altrimenti dai dati.
  DateTime first;
  if (range.start != null) {
    first = _bucketStartOf(range.start!, granularity);
  } else if (acc.isNotEmpty) {
    first = acc.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  } else {
    first = _bucketStartOf(current, granularity);
  }

  DateTime lastExclusive;
  if (range.endExclusive != null) {
    final lastDay = DateTime(
      range.endExclusive!.year,
      range.endExclusive!.month,
      range.endExclusive!.day - 1,
    );
    lastExclusive = _nextBucket(_bucketStartOf(lastDay, granularity), granularity);
  } else if (acc.isNotEmpty) {
    final maxStart = acc.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    lastExclusive = _nextBucket(maxStart, granularity);
  } else {
    lastExclusive = _nextBucket(first, granularity);
  }

  // Inizi dei bucket (anche vuoti) lungo tutta la timeline.
  final starts = <DateTime>[];
  var b = first;
  var guard = 0;
  while (b.isBefore(lastExclusive) && guard < 600) {
    starts.add(b);
    b = _nextBucket(b, granularity);
    guard++;
  }

  // Suffisso anno sulle etichette mensili solo se la timeline cambia anno.
  final multiYear = starts.isNotEmpty && starts.first.year != starts.last.year;

  return [
    for (final s in starts)
      PeriodBucket(
        start: s,
        label: _bucketLabel(s, granularity, multiYear),
        outcome: (acc[s] ?? const [0.0, 0.0])[0],
        income: (acc[s] ?? const [0.0, 0.0])[1],
      ),
  ];
}
