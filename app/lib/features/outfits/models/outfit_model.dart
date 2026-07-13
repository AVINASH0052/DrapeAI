import '../../wardrobe/models/item_model.dart';

class Outfit {
  final String id;
  final List<Item> items;
  final String? reason;
  final double ruleScore;
  final String occasion;
  final Map<String, dynamic>? weather;
  final String? previewUrl;

  Outfit({
    required this.id,
    required this.items,
    this.reason,
    this.ruleScore = 0,
    required this.occasion,
    this.weather,
    this.previewUrl,
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
      previewUrl: json['preview_url'] as String?,
    );
  }

  Outfit copyWith({List<Item>? items, String? reason, String? previewUrl}) {
    return Outfit(
      id: id,
      items: items ?? this.items,
      reason: reason ?? this.reason,
      ruleScore: ruleScore,
      occasion: occasion,
      weather: weather,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
