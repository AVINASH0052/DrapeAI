import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Current month being viewed in the calendar.
final calendarMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

/// Fetches calendar entries for the given month string (YYYY-MM).
final calendarEntriesProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, month) async {
  final api = ref.read(apiClientProvider);
  return await api.getCalendarMonth(month);
});
