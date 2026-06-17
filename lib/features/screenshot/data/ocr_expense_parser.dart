// Parser euristico che trasforma il testo OCR di uno screenshot (lista movimenti
// / estratto conto) in voci di spesa/entrata. Dart puro, senza dipendenze da ML
// Kit, cosi' la logica e' unit-testabile (vedi test/ocr_expense_parser_test.dart).
//
// Tarato sui layout regolari delle app bancarie (gli screenshot dell'utente sono
// sempre di buona qualita'). Modello a due colonne: a destra gli importi, a
// sinistra titolo + eventuale sottotitolo/data. Ogni importo e' una transazione,
// che "raccoglie" le righe di testo verticalmente vicine. Le date possono essere:
//  - nel testo della voce, numeriche (10/05) o testuali (15 giu, 29 mai);
//  - in una riga-intestazione di sezione (es. "Vendredi 29 mai"), che vale per
//    tutte le voci sottostanti finche' non arriva la successiva.
//
// Le categorie NON vengono assegnate qui (sempre null): la categorizzazione e'
// uno stadio separato, condiviso con il percorso Claude, da agganciare in futuro.

import 'dart:ui';

import '../../expenses/domain/expense.dart';
import '../domain/extracted_expense.dart';

/// Una riga di testo riconosciuta dall'OCR, con la sua posizione sull'immagine.
/// E' il modello intermedio tra ML Kit (`TextLine`) e il parser, scelto per
/// tenere il parser indipendente dal plugin nativo.
class OcrLine {
  const OcrLine(this.text, this.rect);

  final String text;
  final Rect rect;
}

// Importo in valuta italiana: segno opzionale, € opzionale (prima o dopo),
// parte intera con eventuali separatori di migliaia (punto/spazio) e SEMPRE due
// decimali dopo la virgola. I due decimali sono richiesti di proposito: sono il
// segnale forte che distingue un importo da una data o da un numero qualsiasi,
// e gli estratti conto mostrano sempre i centesimi.
final _moneyRe = RegExp(
  r'([+-])?\s*(?:€|EUR)?\s*(\d{1,3}(?:[.\s]\d{3})+|\d+)\s*,\s*(\d{2})\s*(?:€|EUR)?',
);

// Data numerica: gg/mm, gg/mm/aa, gg/mm/aaaa (anche con '.' o '-').
final _numDateRe = RegExp(r'(\d{1,2})[\/.\-](\d{1,2})(?:[\/.\-](\d{2,4}))?');

// Data testuale: giorno + mese in lettere (it/fr), es. "15 giu", "29 mai",
// "3 gennaio". L'anno e' opzionale.
final _textDateRe = RegExp(
  r'(\d{1,2})\s+([A-Za-zàáâäèéêëìíîïòóôöùúûüç]{3,})\.?(?:\s+(\d{4}))?',
);

final _multiSpaceRe = RegExp(r'\s+');
final _edgeSepRe = RegExp(r'^[·\-–—:|]+|[·\-–—:|]+$');
final _trailingPrepRe = RegExp(r'\s+(?:du|del|dal)$', caseSensitive: false);
final _thousandsSepRe = RegExp(r'[.\s]');

// Stem dei mesi (italiano + francese), normalizzati senza accenti. Confrontati
// per prefisso, dal piu' lungo al piu' corto per evitare collisioni (juin/juil).
const _monthStems = <String, int>{
  'gennaio': 1, 'gen': 1, 'janvier': 1, 'janv': 1, 'jan': 1,
  'febbraio': 2, 'feb': 2, 'fevrier': 2, 'fevr': 2, 'fev': 2,
  'marzo': 3, 'mars': 3, 'mar': 3,
  'aprile': 4, 'apr': 4, 'avril': 4, 'avr': 4,
  'maggio': 5, 'mag': 5, 'mai': 5, 'may': 5,
  'giugno': 6, 'giu': 6, 'juin': 6,
  'luglio': 7, 'lug': 7, 'juillet': 7, 'juil': 7,
  'agosto': 8, 'ago': 8, 'aout': 8, 'aou': 8,
  'settembre': 9, 'sett': 9, 'set': 9, 'septembre': 9, 'sept': 9, 'sep': 9,
  'ottobre': 10, 'ott': 10, 'octobre': 10, 'oct': 10,
  'novembre': 11, 'nov': 11,
  'dicembre': 12, 'dic': 12, 'decembre': 12, 'dec': 12,
};

class _DateHit {
  _DateHit(this.date, this.start, this.end);
  final DateTime date;
  final int start;
  final int end;
}

/// Estrae le voci dalle righe OCR.
List<ExtractedExpense> parseOcrLines(
  List<OcrLine> lines, {
  required int currentYear,
}) {
  final nonEmpty = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (nonEmpty.isEmpty) return const [];

  // 1. Classifica le righe in "importi" (transazioni) e righe di testo.
  final txns = <_Txn>[];
  final textLines = <OcrLine>[];
  for (final line in nonEmpty) {
    final matches = _moneyRe.allMatches(line.text).toList();
    if (matches.isEmpty) {
      textLines.add(line);
      continue;
    }
    // L'importo del movimento e' il valore piu' a destra (ultimo nel testo).
    final m = matches.last;
    final intPart = m.group(2)!.replaceAll(_thousandsSepRe, '');
    final value = double.parse('$intPart.${m.group(3)}');
    final type = m.group(1) == '+' ? ExpenseType.income : ExpenseType.expense;
    final leftover = line.text.replaceRange(m.start, m.end, ' ');
    txns.add(_Txn(line, leftover, value, type));
  }
  if (txns.isEmpty) return const [];

  txns.sort((a, b) => a.cy.compareTo(b.cy));

  // 2. Stima la "spaziatura" tra transazioni per dimensionare la banda verticale
  //    entro cui una riga di testo appartiene alla stessa voce dell'importo.
  final double spacing;
  if (txns.length >= 2) {
    final deltas = <double>[
      for (var i = 1; i < txns.length; i++) txns[i].cy - txns[i - 1].cy,
    ]..sort();
    spacing = deltas[deltas.length ~/ 2];
  } else {
    spacing = _medianHeight(nonEmpty) * 3;
  }
  final band = spacing * 0.5;

  // 3. Assegna ogni riga di testo all'importo verticalmente piu' vicino, se
  //    entro la banda; altrimenti e' una riga "libera" (candidata header).
  final headers = <OcrLine>[];
  for (final tl in textLines) {
    var bestIdx = -1;
    var bestDist = double.infinity;
    for (var i = 0; i < txns.length; i++) {
      final d = (tl.rect.center.dy - txns[i].cy).abs();
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    if (bestIdx >= 0 && bestDist <= band) {
      txns[bestIdx].extra.add(tl);
    } else {
      headers.add(tl);
    }
  }

  // 4. Date-intestazione di sezione: righe libere che contengono una data.
  final headerDates = <_HeaderDate>[];
  for (final h in headers) {
    final hit = _findDate(h.text, currentYear);
    if (hit != null) headerDates.add(_HeaderDate(h.rect.center.dy, hit.date));
  }
  headerDates.sort((a, b) => a.cy.compareTo(b.cy));

  // 5. Costruisce le voci.
  final out = <ExtractedExpense>[];
  for (final txn in txns) {
    final parts = <OcrLine>[OcrLine(txn.leftover, txn.line.rect), ...txn.extra]
      ..sort((a, b) {
        final dy = a.rect.center.dy.compareTo(b.rect.center.dy);
        return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
      });
    var text = parts.map((p) => p.text.trim()).where((t) => t.isNotEmpty).join(' ');

    final inline = _findDate(text, currentYear);
    DateTime? date;
    if (inline != null) {
      date = inline.date;
      text = text.replaceRange(inline.start, inline.end, ' ');
    } else {
      date = _headerDateAbove(headerDates, txn.cy);
    }

    final title = _cleanTitle(text);
    out.add(ExtractedExpense(
      title: title,
      amount: txn.value,
      date: date,
      type: txn.type,
    ));
  }
  return out;
}

class _Txn {
  _Txn(this.line, this.leftover, this.value, this.type);
  final OcrLine line;
  final String leftover;
  final double value;
  final ExpenseType type;
  final List<OcrLine> extra = [];
  double get cy => line.rect.center.dy;
}

class _HeaderDate {
  _HeaderDate(this.cy, this.date);
  final double cy;
  final DateTime date;
}

/// Data dell'intestazione di sezione piu' vicina sopra la voce (cy minore).
DateTime? _headerDateAbove(List<_HeaderDate> headers, double cy) {
  DateTime? result;
  for (final h in headers) {
    if (h.cy < cy) {
      result = h.date;
    } else {
      break;
    }
  }
  return result;
}

double _medianHeight(List<OcrLine> lines) {
  final heights = lines.map((l) => l.rect.height).where((h) => h > 0).toList()
    ..sort();
  return heights.isEmpty ? 20.0 : heights[heights.length ~/ 2];
}

String _cleanTitle(String text) {
  var title = text.replaceAll(_multiSpaceRe, ' ').trim();
  title = title.replaceAll(_edgeSepRe, '').trim();
  title = title.replaceAll(_trailingPrepRe, '').trim();
  return title;
}

/// Cerca una data nel testo: prima numerica, poi testuale (mese in lettere).
_DateHit? _findDate(String text, int currentYear) {
  for (final m in _numDateRe.allMatches(text)) {
    final d = _parseNumericDate(m, currentYear);
    if (d != null) return _DateHit(d, m.start, m.end);
  }
  for (final m in _textDateRe.allMatches(text)) {
    final d = _parseTextualDate(m, currentYear);
    if (d != null) return _DateHit(d, m.start, m.end);
  }
  return null;
}

DateTime? _parseNumericDate(RegExpMatch m, int currentYear) {
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final rawYear = m.group(3);
  var year = currentYear;
  if (rawYear != null) {
    year = int.parse(rawYear);
    if (year < 100) year += 2000;
  }
  return _buildDate(year, month, day);
}

DateTime? _parseTextualDate(RegExpMatch m, int currentYear) {
  final day = int.parse(m.group(1)!);
  final month = _monthFromWord(m.group(2)!);
  if (month == null) return null;
  final rawYear = m.group(3);
  final year = rawYear != null ? int.parse(rawYear) : currentYear;
  return _buildDate(year, month, day);
}

DateTime? _buildDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final dt = DateTime(year, month, day);
  // Scarta date impossibili (es. 31/02 normalizzato da DateTime).
  if (dt.month != month || dt.day != day) return null;
  return dt;
}

int? _monthFromWord(String word) {
  final w = _stripAccents(word.toLowerCase());
  // Confronto per prefisso, stem piu' lunghi prima (juin vs juil, set vs sett).
  final stems = _monthStems.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final stem in stems) {
    if (w.startsWith(stem)) return _monthStems[stem];
  }
  return null;
}

String _stripAccents(String s) => s
    .replaceAll(RegExp('[àáâä]'), 'a')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[òóôö]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u')
    .replaceAll('ç', 'c');
