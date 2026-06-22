/// Etichetta a testo libero applicabile alle spese (vedi DATABASE_SCHEMA.md).
/// Dizionario per-budget: alimenta autocomplete nei form e filtri nei grafici.
class Tag {
  const Tag({required this.id, required this.name});

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  final String id;
  final String name;
}
