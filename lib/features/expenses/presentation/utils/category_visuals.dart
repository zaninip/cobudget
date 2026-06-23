import 'package:flutter/material.dart';

/// Mappa il campo `icon` (stringa) di [ExpenseCategory] su una [IconData] di Material Icons.
/// Solo icone del set classico Material Icons (no Material Symbols).
const _categoryIcons = <String, IconData>{
  // Generiche
  'category': Icons.category,
  'star': Icons.star,
  'favorite': Icons.favorite,
  'label': Icons.label,
  'bookmark': Icons.bookmark,
  'flag': Icons.flag,
  'sunny': Icons.sunny,
  'eco': Icons.eco,

  // Spesa / acquisti
  'shopping_cart': Icons.shopping_cart,
  'shopping_bag': Icons.shopping_bag,
  'local_grocery_store': Icons.local_grocery_store,
  'store': Icons.store,
  'storefront': Icons.storefront,
  'local_mall': Icons.local_mall,
  'local_offer': Icons.local_offer,
  'sell': Icons.sell,
  'redeem': Icons.redeem,
  'card_giftcard': Icons.card_giftcard,
  'receipt_long': Icons.receipt_long,

  // Cibo / bevande
  'restaurant': Icons.restaurant,
  'restaurant_menu': Icons.restaurant_menu,
  'fastfood': Icons.fastfood,
  'lunch_dining': Icons.lunch_dining,
  'dinner_dining': Icons.dinner_dining,
  'local_pizza': Icons.local_pizza,
  'bakery_dining': Icons.bakery_dining,
  'ramen_dining': Icons.ramen_dining,
  'icecream': Icons.icecream,
  'cake': Icons.cake,
  'local_cafe': Icons.local_cafe,
  'coffee': Icons.coffee,
  'local_bar': Icons.local_bar,
  'wine_bar': Icons.wine_bar,
  'liquor': Icons.liquor,

  // Trasporti
  'directions_car': Icons.directions_car,
  'electric_car': Icons.electric_car,
  'local_taxi': Icons.local_taxi,
  'directions_bus': Icons.directions_bus,
  'train': Icons.train,
  'tram': Icons.tram,
  'directions_subway': Icons.directions_subway,
  'directions_bike': Icons.directions_bike,
  'pedal_bike': Icons.pedal_bike,
  'two_wheeler': Icons.two_wheeler,
  'flight': Icons.flight,
  'directions_boat': Icons.directions_boat,
  'local_gas_station': Icons.local_gas_station,
  'ev_station': Icons.ev_station,
  'local_parking': Icons.local_parking,
  'local_shipping': Icons.local_shipping,

  // Casa / utenze
  'home': Icons.home,
  'house': Icons.house,
  'apartment': Icons.apartment,
  'cottage': Icons.cottage,
  'villa': Icons.villa,
  'bed': Icons.bed,
  'weekend': Icons.weekend,
  'chair': Icons.chair,
  'kitchen': Icons.kitchen,
  'bathtub': Icons.bathtub,
  'cleaning_services': Icons.cleaning_services,
  'handyman': Icons.handyman,
  'plumbing': Icons.plumbing,
  'electrical_services': Icons.electrical_services,
  'build': Icons.build,
  'lightbulb': Icons.lightbulb,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'local_fire_department': Icons.local_fire_department,
  'ac_unit': Icons.ac_unit,
  'wifi': Icons.wifi,

  // Salute
  'local_hospital': Icons.local_hospital,
  'medical_services': Icons.medical_services,
  'medication': Icons.medication,
  'monitor_heart': Icons.monitor_heart,
  'healing': Icons.healing,
  'vaccines': Icons.vaccines,
  'health_and_safety': Icons.health_and_safety,
  'local_pharmacy': Icons.local_pharmacy,
  'fitness_center': Icons.fitness_center,
  'spa': Icons.spa,
  'self_improvement': Icons.self_improvement,
  'psychology': Icons.psychology,

  // Finanza
  'euro': Icons.euro,
  'savings': Icons.savings,
  'payments': Icons.payments,
  'paid': Icons.paid,
  'credit_card': Icons.credit_card,
  'account_balance': Icons.account_balance,
  'account_balance_wallet': Icons.account_balance_wallet,
  'wallet': Icons.wallet,
  'currency_exchange': Icons.currency_exchange,
  'request_quote': Icons.request_quote,
  'price_check': Icons.price_check,
  'local_atm': Icons.local_atm,

  // Tempo libero / sport / cultura
  'sports_esports': Icons.sports_esports,
  'videogame_asset': Icons.videogame_asset,
  'movie': Icons.movie,
  'theaters': Icons.theaters,
  'music_note': Icons.music_note,
  'headphones': Icons.headphones,
  'sports_soccer': Icons.sports_soccer,
  'sports_basketball': Icons.sports_basketball,
  'sports_tennis': Icons.sports_tennis,
  'pool': Icons.pool,
  'hiking': Icons.hiking,
  'park': Icons.park,
  'celebration': Icons.celebration,
  'festival': Icons.festival,
  'nightlife': Icons.nightlife,
  'casino': Icons.casino,
  'museum': Icons.museum,
  'palette': Icons.palette,
  'photo_camera': Icons.photo_camera,
  'attractions': Icons.attractions,
  'emoji_events': Icons.emoji_events,

  // Tecnologia
  'laptop_windows': Icons.laptop_windows,
  'computer': Icons.computer,
  'phone_iphone': Icons.phone_iphone,
  'tv': Icons.tv,
  'watch': Icons.watch,
  'print': Icons.print,
  'devices': Icons.devices,

  // Viaggi
  'travel_explore': Icons.travel_explore,
  'luggage': Icons.luggage,
  'hotel': Icons.hotel,
  'map': Icons.map,
  'public': Icons.public,
  'explore': Icons.explore,
  'backpack': Icons.backpack,
  'beach_access': Icons.beach_access,
  'language': Icons.language,

  // Istruzione / lavoro
  'school': Icons.school,
  'menu_book': Icons.menu_book,
  'book': Icons.book,
  'science': Icons.science,
  'work': Icons.work,
  'business_center': Icons.business_center,
  'badge': Icons.badge,

  // Abbigliamento / cura
  'checkroom': Icons.checkroom,
  'dry_cleaning': Icons.dry_cleaning,
  'local_laundry_service': Icons.local_laundry_service,
  'content_cut': Icons.content_cut,
  'face': Icons.face,

  // Animali / bambini
  'pets': Icons.pets,
  'child_care': Icons.child_care,
  'child_friendly': Icons.child_friendly,
  'stroller': Icons.stroller,
  'toys': Icons.toys,

  // Natura / varie
  'local_florist': Icons.local_florist,
  'yard': Icons.yard,
  'agriculture': Icons.agriculture,
  'recycling': Icons.recycling,
  'diamond': Icons.diamond,
  'calendar_month': Icons.calendar_month,
  'event': Icons.event,
  'subscriptions': Icons.subscriptions,
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
