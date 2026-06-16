import 'package:cobudget/features/expenses/domain/expense.dart';
import 'package:cobudget/features/screenshot/domain/extracted_expense.dart';
import 'package:cobudget/features/screenshot/presentation/utils/dedup.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _existing({required DateTime date, required double amount}) {
  return Expense(
    id: 'x',
    budgetId: 'b1',
    title: 'x',
    amount: amount,
    date: date,
    categoryId: 'cat',
  );
}

ExtractedExpense _extracted({DateTime? date, required double amount}) {
  return ExtractedExpense(title: 't', amount: amount, date: date);
}

void main() {
  group('dedupExtracted', () {
    test('esclude le voci con stessa data e importo gia’ presenti', () {
      final existing = [_existing(date: DateTime(2026, 6, 10), amount: 12.50)];
      final extracted = [
        _extracted(date: DateTime(2026, 6, 10), amount: 12.50), // duplicato
        _extracted(date: DateTime(2026, 6, 10), amount: 9.99), // importo diverso
        _extracted(date: DateTime(2026, 6, 11), amount: 12.50), // data diversa
      ];

      final result = dedupExtracted(extracted, existing);

      expect(result.excluded, 1);
      expect(result.kept.length, 2);
    });

    test('tiene le voci senza data (non deduplicabili)', () {
      final existing = [_existing(date: DateTime(2026, 6, 10), amount: 12.50)];
      final extracted = [_extracted(date: null, amount: 12.50)];

      final result = dedupExtracted(extracted, existing);

      expect(result.excluded, 0);
      expect(result.kept.length, 1);
    });

    test('collassa i doppioni esatti interni allo stesso batch', () {
      final extracted = [
        _extracted(date: DateTime(2026, 6, 10), amount: 5.00),
        _extracted(date: DateTime(2026, 6, 10), amount: 5.00), // doppione nel batch
      ];

      final result = dedupExtracted(extracted, const []);

      expect(result.excluded, 1);
      expect(result.kept.length, 1);
    });
  });
}
