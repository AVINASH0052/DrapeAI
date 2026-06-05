import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Fetches high-level analytics overview stats.
final analyticsOverviewProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  return await api.getAnalyticsOverview();
});

/// Fetches per-category breakdown with cost-per-wear data.
final categoryBreakdownProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  return await api.getCategoryBreakdown();
});
