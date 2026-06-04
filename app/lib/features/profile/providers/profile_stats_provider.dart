import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/profile_stats_model.dart';

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.getProfileStats();
  return ProfileStats.fromJson(data);
});
