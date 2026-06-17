import 'package:cobudget/features/categorization/data/learned_matcher.dart';
import 'package:cobudget/features/categorization/domain/category_learning_repository.dart';
import 'package:flutter_test/flutter_test.dart';

LearnedCategory _cat(String id, [String? sub]) => (categoryId: id, subcategoryId: sub);

void main() {
  group('matchLearned', () {
    final learned = {
      'monoprix': _cat('alimentari'),
      'decathlon': _cat('sport', 'attrezzatura'),
      'carrefour market': _cat('alimentari'),
    };

    test('match esatto', () {
      expect(matchLearned(learned, 'Monoprix'), _cat('alimentari'));
      expect(matchLearned(learned, 'Decathlon'), _cat('sport', 'attrezzatura'));
    });

    test('match dopo dedup dei token (Monoprix MONOPRIX)', () {
      expect(matchLearned(learned, 'Monoprix MONOPRIX'), _cat('alimentari'));
      expect(matchLearned(learned, 'Decathlon decathlon'), _cat('sport', 'attrezzatura'));
    });

    test('fallback a sottoinsieme: chiave appresa contenuta nel titolo letto', () {
      // "monoprix" appreso e' contenuto in "monoprix centre ville".
      expect(matchLearned(learned, 'Monoprix Centre Ville 12/05'), _cat('alimentari'));
    });

    test('preferisce la candidata piu\' specifica (piu\' token)', () {
      // "carrefour market" (2 token) vince su un'eventuale "carrefour" (1 token).
      final m = {
        'carrefour': _cat('generico'),
        'carrefour market': _cat('alimentari'),
      };
      expect(matchLearned(m, 'Carrefour Market Lyon'), _cat('alimentari'));
    });

    test('nessun match => null', () {
      expect(matchLearned(learned, 'Spotify'), isNull);
    });

    test('titolo senza contenuto significativo => null', () {
      expect(matchLearned(learned, '12/05 -10,00'), isNull);
    });

    test('ambiguo a parita\' di specificita\' => null', () {
      final m = {
        'alpha': _cat('uno'),
        'beta': _cat('due'),
      };
      // "alpha beta gamma" contiene sia "alpha" sia "beta" (1 token ciascuno),
      // categorie diverse => rinuncia.
      expect(matchLearned(m, 'Alpha Beta Gamma'), isNull);
    });
  });
}
