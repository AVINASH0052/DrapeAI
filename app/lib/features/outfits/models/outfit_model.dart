import '../../wardrobe/models/item_model.dart';

class Outfit {
  final String id;
  final List<Item> items;
  final String? reason;
  final double ruleScore;
  final String occasion;
  final Map<String, dynamic>? weather;

  Outfit({
    required this.id,
    required this.items,
    this.reason,
    this.ruleScore = 0,
    required this.occasion,
    this.weather,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'],
      items: (json['items'] as List? ?? [])
          .map((j) => Item.fromJson(j))
          .toList(),
      reason: json['reason'],
      ruleScore: (json['rule_score'] ?? 0).toDouble(),
      occasion: json['occasion'] ?? 'casual',
      weather: json['weather'],
    );
  }
}
