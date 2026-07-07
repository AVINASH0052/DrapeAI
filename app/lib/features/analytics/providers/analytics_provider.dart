import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final analyticsOverviewProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.getAnalyticsOverview();
  // Normalize field names for UI
  if (!data.containsKey('utilization_pct') &&
      data.containsKey('wardrobe_utilization_pct')) {
    data['utilization_pct'] = data['wardrobe_utilization_pct'];
  }
  return data;
});

final categoryBreakdownProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final list = await api.getCategoryBreakdown();
  return List<Map<String, dynamic>>.from(list);
});

final wearHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, days) async {
  final api = ref.read(apiClientProvider);
  final list = await api.getWearHistory(days: days);
  return List<Map<String, dynamic>>.from(list);
});
