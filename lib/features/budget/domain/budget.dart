/// Un budget condiviso tra più utenti (vedi DATABASE_SCHEMA.md).
class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
  });

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String name;
  final String inviteCode;
  final DateTime createdAt;
}
