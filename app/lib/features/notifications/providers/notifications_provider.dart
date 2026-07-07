import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Unread notification count for badge display.
final unreadCountProvider = FutureProvider<int>((ref) async {
  final api = ref.read(apiClientProvider);
  return api.getUnreadCount();
});

/// Paginated notification list.
final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.getNotifications(limit: 50, offset: 0);
  return List<Map<String, dynamic>>.from(data['notifications']);
});
