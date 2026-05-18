import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/item_model.dart';

final wardrobeCategoryFilter = StateProvider<String?>((ref) => null);
final wardrobeSearchQuery = StateProvider<String>((ref) => '');

final wardrobeProvider =
    AsyncNotifierProvider<WardrobeNotifier, List<Item>>(WardrobeNotifier.new);

class WardrobeNotifier extends AsyncNotifier<List<Item>> {
  @override
  Future<List<Item>> build() async {
    final category = ref.watch(wardrobeCategoryFilter);
    final search = ref.watch(wardrobeSearchQuery);

    final api = ref.read(apiClientProvider);
    final data = await api.getItems(
      category: category,
      search: search.isNotEmpty ? search : null,
    );
    return (data['items'] as List).map((j) => Item.fromJson(j)).toList();
  }

  Future<void> deleteItem(String id) async {
    final api = ref.read(apiClientProvider);
    await api.deleteItem(id);
    state = AsyncValue.data(
        state.value?.where((i) => i.id != id).toList() ?? []);
  }

  void refresh() => ref.invalidateSelf();
}
