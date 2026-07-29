import 'dart:convert';

class Item {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String category;
  final String subCategory;
  final String? displayName;
  final String? notes;
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
  final String processingStatus;

  Item({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    required this.subCategory,
    this.displayName,
    this.notes,
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
    this.processingStatus = 'ready',
  });

  bool get isProcessing =>
      processingStatus == 'queued' || processingStatus == 'processing';

  bool get isFailed => processingStatus == 'failed';

  /// API may return JSONB list fields as real lists or as encoded strings.
  static List<String> _stringList(dynamic value, [List<String>? fallback]) {
    if (value == null) return fallback ?? const [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback ?? const [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return fallback ?? const [];
      }
    }
    return fallback ?? const [];
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      category: json['category'] as String,
      subCategory: (json['sub_category'] as String?) ?? '',
      displayName: json['display_name'] as String?,
      notes: json['notes'] as String?,
      primaryColor: json['primary_color'] as String,
      secondaryColors: _stringList(json['secondary_colors']),
      pattern: (json['pattern'] as String?) ?? 'solid',
      fabric: (json['fabric'] as String?) ?? 'cotton',
      styleTags: _stringList(json['style_tags']),
      formality: (json['formality'] as int?) ?? 3,
      seasonTags: _stringList(json['season_tags'], const ['all_season']),
      ethnicFlag: (json['ethnic_flag'] as bool?) ?? false,
      wearCount: (json['wear_count'] as int?) ?? 0,
      lastWornAt: json['last_worn_at'] != null
          ? DateTime.parse(json['last_worn_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      processingStatus: (json['processing_status'] as String?) ?? 'ready',
    );
  }
}
