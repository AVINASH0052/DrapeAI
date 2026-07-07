class Item {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String category;
  final String subCategory;
  final String primaryColor;
  final List<String> secondaryColors;
  final String pattern;
  final String fabric;
  final List<String> styleTags;
  final int formality;
  final List<String> seasonTags;
  final bool ethnicFlag;
  final int wearCount;
  final DateTime? lastWornAt;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    required this.subCategory,
    required this.primaryColor,
    this.secondaryColors = const [],
    this.pattern = 'solid',
    this.fabric = 'cotton',
    this.styleTags = const [],
    this.formality = 3,
    this.seasonTags = const ['all_season'],
    this.ethnicFlag = false,
    this.wearCount = 0,
    this.lastWornAt,
    required this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      imageUrl: json['image_url'],
      thumbnailUrl: json['thumbnail_url'],
      category: json['category'],
      subCategory: json['sub_category'] ?? '',
      primaryColor: json['primary_color'],
      secondaryColors: List<String>.from(json['secondary_colors'] ?? []),
      pattern: json['pattern'] ?? 'solid',
      fabric: json['fabric'] ?? 'cotton',
      styleTags: List<String>.from(json['style_tags'] ?? []),
      formality: json['formality'] ?? 3,
      seasonTags: List<String>.from(json['season_tags'] ?? ['all_season']),
      ethnicFlag: json['ethnic_flag'] ?? false,
      wearCount: json['wear_count'] ?? 0,
      lastWornAt: json['last_worn_at'] != null
          ? DateTime.parse(json['last_worn_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
