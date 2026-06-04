class ProfileStats {
  final int totalItems;
  final int savedOutfits;
  final int utilizationPct;

  ProfileStats({
    required this.totalItems,
    required this.savedOutfits,
    required this.utilizationPct,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      totalItems: json['total_items'] ?? 0,
      savedOutfits: json['saved_outfits'] ?? 0,
      utilizationPct: json['utilization_pct'] ?? 0,
    );
  }
}
