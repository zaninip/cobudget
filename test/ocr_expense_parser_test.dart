import 'dart:ui';

import 'package:cobudget/features/expenses/domain/expense.dart';
import 'package:cobudget/features/screenshot/data/ocr_expense_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper: crea una OcrLine a una data colonna (x) e riga (y), altezza fissa.
OcrLine _line(String text, {double x = 0, double y = 0, double w = 200}) =>
    OcrLine(text, Rect.fromLTWH(x, y, w, 20));

void main() {
  const year = 2026;

  group('parseOcrLines - riga singola', () {
    test('descrizione, data numerica e importo con segno -', () {
      final items = parseOcrLines(
        [_line('Supermercato 12/05 -42,00')],
        currentYear: year,
      );
      expect(items, hasLength(1));
      expect(items.first.title, 'Supermercato');
      expect(items.first.amount, 42.00);
      expect(items.first.type, ExpenseType.expense);
      expect(items.first.date, DateTime(2026, 5, 12));
    });

    test('segno + => entrata, importo con separatore di migliaia', () {
      final items = parseOcrLines(
        [_line('Stipendio 01/06 +1.500,00')],
        currentYear: year,
      );
      expect(items.single.type, ExpenseType.income);
      expect(items.single.amount, 1500.00);
      expect(items.single.date, DateTime(2026, 6, 1));
    });

    test('senza segno => default uscita', () {
      final items = parseOcrLines([_line('Benzina 55,00 €')], currentYear: year);
      expect(items.single.type, ExpenseType.expense);
      expect(items.single.amount, 55.00);
    });

    test('data con anno a 2 cifre', () {
      final items = parseOcrLines(
        [_line('Farmacia 03/04/24 -9,90')],
        currentYear: year,
      );
      expect(items.single.date, DateTime(2024, 4, 3));
    });

    test('senza data => date null', () {
      final items = parseOcrLines([_line('Abbonamento -9,99')], currentYear: year);
      expect(items.single.date, isNull);
      expect(items.single.amount, 9.99);
    });

    test('importo piu\' a destra quando ce ne sono due sulla stessa riga', () {
      final items = parseOcrLines(
        [_line('1.000,00 Prelievo -50,00')],
        currentYear: year,
      );
      expect(items.single.amount, 50.00);
      expect(items.single.title, contains('Prelievo'));
    });

    test('data impossibile non viene interpretata come data', () {
      final items = parseOcrLines([_line('Note 31/02 -5,00')], currentYear: year);
      expect(items.single.date, isNull);
    });
  });

  group('parseOcrLines - date testuali (mese in lettere)', () {
    test('mese italiano abbreviato "giu"', () {
      final items = parseOcrLines([_line('Campus Est 15 giu 40,00 €')], currentYear: year);
      expect(items.single.title, 'Campus Est');
      expect(items.single.amount, 40.00);
      expect(items.single.date, DateTime(2026, 6, 15));
    });

    test('mese francese "mai"', () {
      final items = parseOcrLines([_line('CB Relais 29 mai 45,10 €')], currentYear: year);
      expect(items.single.date, DateTime(2026, 5, 29));
    });

    test('mese francese juin/juillet senza collisione di prefisso', () {
      final juin = parseOcrLines([_line('A 1 juin 1,00 €')], currentYear: year);
      final juil = parseOcrLines([_line('B 1 juillet 2,00 €')], currentYear: year);
      expect(juin.single.date, DateTime(2026, 6, 1));
      expect(juil.single.date, DateTime(2026, 7, 1));
    });

    test('mese inglese giorno-mese con anno esplicito', () {
      final items = parseOcrLines([_line('Netflix 15 June 2025 -12,99')], currentYear: year);
      expect(items.single.date, DateTime(2025, 6, 15));
      expect(items.single.title, 'Netflix');
    });

    test('mese inglese mese-giorno (June 15)', () {
      final items = parseOcrLines([_line('Amazon June 15 -30,00')], currentYear: year);
      expect(items.single.date, DateTime(2026, 6, 15));
    });

    test('mese inglese mese-giorno con anno e virgola (Jun 15, 2025)', () {
      final items = parseOcrLines([_line('Spotify Jun 15, 2025 -9,99')], currentYear: year);
      expect(items.single.date, DateTime(2025, 6, 15));
    });
  });

  group('parseOcrLines - data ISO', () {
    test('formato aaaa-mm-gg', () {
      final items = parseOcrLines([_line('Bonifico 2025-06-15 -50,00')], currentYear: year);
      expect(items.single.date, DateTime(2025, 6, 15));
      expect(items.single.title, 'Bonifico');
    });

    test('ISO non interpretato come gg/mm dal parser numerico', () {
      final items = parseOcrLines([_line('Acquisto 2024-03-09 -1,00')], currentYear: year);
      expect(items.single.date, DateTime(2024, 3, 9));
    });
  });

  group('parseOcrLines - layout a piu\' righe', () {
    test('titolo e data su righe distinte vengono uniti alla stessa voce', () {
      // Stile app: titolo sopra, data sotto, importo a destra.
      final items = parseOcrLines(
        [
          _line('Campus Est', x: 0, y: 250),
          _line('15 giu', x: 0, y: 298),
          _line('40,00 €', x: 700, y: 270),
        ],
        currentYear: year,
      );
      expect(items, hasLength(1));
      expect(items.single.title, 'Campus Est');
      expect(items.single.amount, 40.00);
      expect(items.single.date, DateTime(2026, 6, 15));
    });

    test('data-intestazione di sezione propagata alle voci senza data propria', () {
      final items = parseOcrLines(
        [
          _line('Vendredi 29 mai', x: 0, y: 395),
          // Voce 1: nessuna data nel titolo -> eredita l'header.
          _line('Virement de Paolo Zanini', x: 0, y: 485),
          _line('Virement reçu', x: 0, y: 530),
          _line('+ 15,00 €', x: 700, y: 490),
          // Voce 2: data nel titolo -> ha la precedenza sull'header.
          _line('CB Station Carrefour du 10/05', x: 0, y: 625),
          _line('- 20,66 €', x: 700, y: 625),
        ],
        currentYear: year,
      );
      expect(items, hasLength(2));
      expect(items[0].type, ExpenseType.income);
      expect(items[0].amount, 15.00);
      expect(items[0].date, DateTime(2026, 5, 29));
      expect(items[0].title, contains('Virement de Paolo Zanini'));
      expect(items[1].type, ExpenseType.expense);
      expect(items[1].amount, 20.66);
      expect(items[1].date, DateTime(2026, 5, 10));
      expect(items[1].title, 'CB Station Carrefour');
    });
  });

  group('parseOcrLines - varie', () {
    test('righe senza importo (saldi/intestazioni) => nessuna voce', () {
      final items = parseOcrLines(
        [_line('Saldo disponibile', y: 0), _line('Movimenti', y: 50)],
        currentYear: year,
      );
      expect(items, isEmpty);
    });

    test('categorie sempre null (stadio separato)', () {
      final items = parseOcrLines([_line('Spesa -1,00')], currentYear: year);
      expect(items.single.categoryId, isNull);
      expect(items.single.subcategoryId, isNull);
    });

    test('lista vuota => nessuna voce', () {
      expect(parseOcrLines(const [], currentYear: year), isEmpty);
    });
  });
}
