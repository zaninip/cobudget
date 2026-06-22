import 'package:flutter/material.dart';

/// Mappa il campo `icon` (stringa) di [ExpenseCategory] su una [IconData] di Material Icons.
const _categoryIcons = <String, IconData>{
  'shopping_cart': Icons.shopping_cart,
  'directions_car': Icons.directions_car,
  'home': Icons.home,
  'favorite': Icons.favorite,
  'sports_esports': Icons.sports_esports,
  'category': Icons.category,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'school': Icons.school,
  'pets': Icons.pets,
  'fitness_center': Icons.fitness_center,
  'flight': Icons.flight,
  'local_hospital': Icons.local_hospital,
  'medication': Icons.medication,
  'travel_explore': Icons.travel_explore,
  'luggage': Icons.luggage,
  'build': Icons.build,
  'savings': Icons.savings,
  'card_giftcard': Icons.card_giftcard,
  'music_note': Icons.music_note,
  'movie': Icons.movie,
  'local_grocery_store': Icons.local_grocery_store,
  'checkroom': Icons.checkroom,
  'phone_iphone': Icons.phone_iphone,
  'celebration': Icons.celebration,
  'bolt': Icons.bolt,
  'euro': Icons.euro,
  'star': Icons.star,
  'sunny': Icons.sunny,
  'laptop_windows': Icons.laptop_windows,
  'monitor_heart': Icons.monitor_heart,
  'bed': Icons.bed,
};

/// Icone proposte all'utente quando crea una nuova categoria.
final availableCategoryIcons = List.unmodifiable(_categoryIcons.keys);

/// Colori proposti all'utente quando crea una nuova categoria.
const availableCategoryColors = <String>[
  '#7C3AED',
  '#2563EB',
  '#16A34A',
  '#DC2626',
  '#F59E0B',
  '#6B7280',
  '#DB2777',
  '#0891B2',
  '#65A30D',
  '#EA580C',
  '#4F46E5',
  '#0D9488',
  '#92400E',
  '#CA8A04',
  '#C026D3',
];

IconData categoryIcon(String icon) => _categoryIcons[icon] ?? Icons.category;

/// Converte il campo `color` (es. `#7C3AED`) di [ExpenseCategory] in un [Color].
Color categoryColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}
