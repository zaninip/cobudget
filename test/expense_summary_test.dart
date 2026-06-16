import 'package:cobudget/features/expenses/domain/category.dart';
import 'package:cobudget/features/expenses/domain/expense.dart';
import 'package:cobudget/features/expenses/presentation/utils/expense_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({
  required String id,
  required DateTime date,
  required double amount,
  ExpenseType type = ExpenseType.expense,
  String categoryId = 'cat-food',
  String? subcategoryId,
}) {
  return Expense(
    id: id,
    budgetId: 'b1',
    title: id,
    amount: amount,
    date: date,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    type: type,
  );
}

const _categories = [
  ExpenseCategory(
    id: 'cat-food',
    name: 'Cibo',
    icon: 'restaurant',
    color: '#16A34A',
    subcategories: [
      Subcategory(id: 'sub-bar', name: 'Bar'),
      Subcategory(id: 'sub-market', name: 'Supermercato'),
    ],
  ),
  ExpenseCategory(
    id: 'cat-car',
    name: 'Auto',
    icon: 'directions_car',
    color: '#2563EB',
    subcategories: [],
  ),
];

void main() {
  // Riferimento temporale fisso per rendere i test deterministici.
  final now = DateTime(2026, 6, 16);

  group('periodRange', () {
    test('questo mese copre solo giugno 2026', () {
      final range = periodRange(SummaryPeriod.thisMonth, now);
      expect(range.contains(DateTime(2026, 6, 1)), isTrue);
      expect(range.contains(DateTime(2026, 6, 30)), isTrue);
      expect(range.contains(DateTime(2026, 5, 31)), isFalse);
      expect(range.contains(DateTime(2026, 7, 1)), isFalse);
    });

    test('ultimi 3 mesi parte da aprile 2026', () {
      final range = periodRange(SummaryPeriod.last3Months, now);
      expect(range.contains(DateTime(2026, 4, 1)), isTrue);
      expect(range.contains(DateTime(2026, 3, 31)), isFalse);
    });

    test('tutto non ha limiti', () {
      final range = periodRange(SummaryPeriod.all, now);
      expect(range.contains(DateTime(2000, 1, 1)), isTrue);
      expect(range.contains(DateTime(2099, 1, 1)), isTrue);
    });
  });

  group('filterExpenses', () {
    final expenses = [
      _expense(id: 'a', date: DateTime(2026, 6, 10), amount: 10),
      _expense(id: 'b', date: DateTime(2026, 5, 10), amount: 20),
      _expense(id: 'c', date: DateTime(2026, 1, 10), amount: 30, categoryId: 'cat-car'),
    ];

    test('filtra per periodo', () {
      final result = filterExpenses(expenses, period: SummaryPeriod.thisMonth, now: now);
      expect(result.map((e) => e.id), ['a']);
    });

    test('filtra per una o più categorie', () {
      final result = filterExpenses(
        expenses,
        period: SummaryPeriod.all,
        categoryIds: {'cat-car'},
        now: now,
      );
      expect(result.map((e) => e.id), ['c']);
    });

    test('filtra per periodo personalizzato (estremi inclusivi)', () {
      final result = filterExpenses(
        expenses,
        period: SummaryPeriod.custom,
        customStart: DateTime(2026, 5, 1),
        customEnd: DateTime(2026, 6, 10),
        now: now,
      );
      expect(result.map((e) => e.id), ['a', 'b']);
    });
  });

  group('computeTotals', () {
    test('separa uscite ed entrate e calcola il saldo', () {
      final totals = computeTotals([
        _expense(id: 'a', date: now, amount: 30),
        _expense(id: 'b', date: now, amount: 12.5),
        _expense(id: 'c', date: now, amount: 100, type: ExpenseType.income),
      ]);
      expect(totals.outcome, 42.5);
      expect(totals.income, 100);
      expect(totals.balance, 57.5);
      expect(totals.isEmpty, isFalse);
    });

    test('lista vuota produce totali a zero', () {
      final totals = computeTotals([]);
      expect(totals.isEmpty, isTrue);
    });
  });

  group('breakdownByCategory', () {
    final expenses = [
      _expense(id: 'a', date: now, amount: 10, categoryId: 'cat-food', subcategoryId: 'sub-bar'),
      _expense(id: 'b', date: now, amount: 30, categoryId: 'cat-food', subcategoryId: 'sub-market'),
      _expense(id: 'c', date: now, amount: 60, categoryId: 'cat-car'),
      _expense(id: 'd', date: now, amount: 5, categoryId: 'cat-food', type: ExpenseType.income),
    ];

    test('per categoria, solo uscite, ordinata dal più grande', () {
      final slices = breakdownByCategory(
        expenses,
        categories: _categories,
        type: ExpenseType.expense,
      );
      expect(slices.map((s) => s.key), ['cat-car', 'cat-food']);
      expect(slices.first.amount, 60);
      expect(slices.last.amount, 40); // 10 + 30
      expect(slices.last.label, 'Cibo');
      expect(slices.last.colorHex, '#16A34A');
    });

    test('percentuale calcolata sul totale', () {
      final slices = breakdownByCategory(
        expenses,
        categories: _categories,
        type: ExpenseType.expense,
      );
      expect(slices.first.percentOf(120), 50);
    });

    test('con categoria selezionata raggruppa per sottocategoria', () {
      // Nella schermata le voci arrivano già pre-filtrate per categoria.
      final foodExpenses =
          expenses.where((e) => e.categoryId == 'cat-food').toList();
      final slices = breakdownByCategory(
        foodExpenses,
        categories: _categories,
        type: ExpenseType.expense,
        categoryId: 'cat-food',
      );
      expect(slices.map((s) => s.key), ['sub-market', 'sub-bar']);
      expect(slices.first.label, 'Supermercato');
    });

    test('voci senza sottocategoria finiscono nel gruppo neutro', () {
      final slices = breakdownByCategory(
        [_expense(id: 'x', date: now, amount: 7, categoryId: 'cat-food')],
        categories: _categories,
        type: ExpenseType.expense,
        categoryId: 'cat-food',
      );
      expect(slices.single.key, '');
      expect(slices.single.label, 'Senza sottocategoria');
      expect(slices.single.colorHex, isNull);
    });
  });

  group('bucketByTime', () {
    test('mensile copre tutti i mesi del periodo, anche vuoti', () {
      final buckets = bucketByTime(
        [
          _expense(id: 'a', date: DateTime(2026, 4, 5), amount: 10),
          _expense(id: 'b', date: DateTime(2026, 6, 5), amount: 20, type: ExpenseType.income),
        ],
        period: SummaryPeriod.last3Months,
        granularity: TrendGranularity.month,
        now: now,
      );
      expect(buckets.length, 3); // apr, mag, giu
      expect(buckets[0].outcome, 10);
      expect(buckets[1].isEmpty, isTrue);
      expect(buckets[2].income, 20);
      expect(buckets.map((b) => b.label), ['apr', 'mag', 'giu']);
    });

    test('settimanale usa il lunedì ISO come inizio bucket', () {
      // 16/06/2026 è un martedì → lunedì della settimana = 15/06.
      final buckets = bucketByTime(
        [_expense(id: 'a', date: DateTime(2026, 6, 16), amount: 10)],
        period: SummaryPeriod.thisMonth,
        granularity: TrendGranularity.week,
        now: now,
      );
      final withData = buckets.where((b) => !b.isEmpty).toList();
      expect(withData.single.outcome, 10);
      expect(withData.single.label, '15/06');
    });

    test('etichette mensili includono l\'anno se la timeline cambia anno', () {
      final buckets = bucketByTime(
        [
          _expense(id: 'a', date: DateTime(2025, 12, 5), amount: 10),
          _expense(id: 'b', date: DateTime(2026, 2, 5), amount: 20),
        ],
        period: SummaryPeriod.all,
        granularity: TrendGranularity.month,
        now: now,
      );
      // Va da dic 2025 a feb 2026 → suffisso anno.
      expect(buckets.length, 3); // dic, gen, feb
      expect(buckets.first.label, 'dic 25');
      expect(buckets.last.label, 'feb 26');
    });
  });
}
