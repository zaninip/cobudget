/// Un membro di un budget condiviso (vedi UI_DESIGN.md - sezione 9).
class BudgetMember {
  const BudgetMember({
    required this.userId,
    required this.name,
    required this.joinedAt,
    required this.isSelf,
  });

  factory BudgetMember.fromMap(Map<String, dynamic> map) {
    return BudgetMember(
      userId: map['user_id'] as String,
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Membro',
      joinedAt: DateTime.parse(map['joined_at'] as String),
      isSelf: map['is_self'] as bool,
    );
  }

  final String userId;
  final String name;
  final DateTime joinedAt;

  /// Indica se questo membro è l'utente attualmente autenticato.
  final bool isSelf;
}
