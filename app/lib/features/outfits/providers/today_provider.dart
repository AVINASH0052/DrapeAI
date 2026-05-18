import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/outfit_model.dart';

final selectedOccasionProvider = StateProvider<String>((ref) => 'casual');

final todayOutfitsProvider = FutureProvider<List<Outfit>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.getTodayOutfits();
  return (data['outfits'] as List)
      .map((j) => Outfit.fromJson(j))
      .toList();
});
