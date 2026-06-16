import '../../expenses/domain/expense.dart';

/// Voce estratta da uno screenshot, in attesa di review. I campi sono mutabili
/// perche' la schermata di review li modifica in place prima del salvataggio.
/// `date`/`categoryId` possono essere null se Claude non li ha ricavati: in quel
/// caso l'utente e' obbligato a compilarli prima di poter salvare.
class ExtractedExpense {
  ExtractedExpense({
    required this.title,
    required this.amount,
    this.date,
    this.type = ExpenseType.expense,
    this.categoryId,
    this.subcategoryId,
  });

  factory ExtractedExpense.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'] as String?;
    return ExtractedExpense(
      title: (map['title'] as String?)?.trim() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: (rawDate != null && rawDate.isNotEmpty) ? DateTime.tryParse(rawDate) : null,
      type: ExpenseType.fromName(map['type'] as String?),
      categoryId: map['categoryId'] as String?,
      subcategoryId: map['subcategoryId'] as String?,
    );
  }

  String title;
  double amount;
  DateTime? date;
  ExpenseType type;
  String? categoryId;
  String? subcategoryId;
}
