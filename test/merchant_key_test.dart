import 'package:cobudget/features/categorization/data/merchant_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('merchantKey', () {
    test('rimuove cifre, date e punteggiatura', () {
      expect(merchantKey('CB Station Carrefour du 10/05'), 'station carrefour');
    });

    test('rimuove prefissi di pagamento e simboli', () {
      expect(merchantKey('PAYPAL *NETFLIX'), 'netflix');
    });

    test('rimuove preposizioni e parole-rumore (Virement de ...)', () {
      expect(merchantKey('Virement de Paolo Zanini'), 'paolo zanini');
    });

    test('normalizza accenti e maiuscole', () {
      expect(merchantKey('Épicerie Çà'), 'epicerie ca');
    });

    test('stesso negoziante con date diverse => stessa chiave', () {
      expect(
        merchantKey('CB Station Hyper U du 09/05'),
        merchantKey('CB Station Hyper U du 28/05'),
      );
    });

    test('collassa spazi multipli e fa trim', () {
      expect(merchantKey('  Mr.   Bricolage  '), 'mr bricolage');
    });

    test('rimuove token duplicati (Monoprix MONOPRIX -> monoprix)', () {
      expect(merchantKey('Monoprix MONOPRIX'), 'monoprix');
      expect(merchantKey('Decathlon decathlon'), 'decathlon');
    });

    test('dedup mantiene l\'ordine di prima comparsa', () {
      expect(merchantKey('Carrefour Market Carrefour'), 'carrefour market');
    });

    test('titolo senza contenuto significativo => stringa vuota', () {
      expect(merchantKey('12/05 -42,00'), '');
      expect(merchantKey('  '), '');
      expect(merchantKey('de du del'), '');
    });
  });
}
