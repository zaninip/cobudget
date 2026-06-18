/// Un budget condiviso tra più utenti (vedi DATABASE_SCHEMA.md).
class Budget {
  const Budget({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdAt,
    this.isAdmin = false,
  });

  factory Budget.fromMap(Map<String, dynamic> map, {bool isAdmin = false}) {
    return Budget(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isAdmin: isAdmin,
    );
  }

  final String id;
  final String name;
  final String inviteCode;
  final DateTime createdAt;

  /// Vero se l'utente corrente è amministratore di questo budget (può eliminarlo,
  /// non solo uscirne). Valorizzato solo dalla lista dei budget dell'utente.
  final bool isAdmin;
}
