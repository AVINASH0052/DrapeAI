import 'package:flutter_test/flutter_test.dart';

import 'package:sugatai/features/outfits/models/outfit_model.dart';
import 'package:sugatai/features/wardrobe/models/item_model.dart';

void main() {
  test('Outfit.copyWith updates previewUrl', () {
    final outfit = Outfit(
      id: '1',
      items: [
        Item(
          id: 'i1',
          imageUrl: '/x.png',
          category: 'top',
          subCategory: 'shirt',
          primaryColor: 'blue',
          createdAt: DateTime(2026),
        ),
      ],
      occasion: 'casual',
    );
    final updated = outfit.copyWith(previewUrl: '/preview.png');
    expect(updated.previewUrl, '/preview.png');
    expect(updated.id, outfit.id);
  });
}
