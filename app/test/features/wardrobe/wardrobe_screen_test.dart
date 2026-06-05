import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drapeai/core/theme/app_theme.dart';
import 'package:drapeai/features/wardrobe/presentation/wardrobe_screen.dart';
import 'package:drapeai/features/wardrobe/providers/wardrobe_provider.dart';
import 'package:drapeai/features/wardrobe/models/item_model.dart';
import 'package:drapeai/features/notifications/providers/notifications_provider.dart';

/// Helper that wraps [WardrobeScreen] in the minimum widget tree needed for
/// testing: a [ProviderScope] with overridden async providers and a
/// [MaterialApp] configured with the app's light theme.
Widget _buildTestableWardrobeScreen({List<Item> items = const []}) {
  return ProviderScope(
    overrides: [
      // Override the wardrobe provider with mock item list.
      wardrobeProvider.overrideWith(() => _FakeWardrobeNotifier(items)),
      // Override the gratification provider so it never triggers the dialog.
      shouldShowGratificationProvider.overrideWith((_) async => false),
      // Override the notification badge count.
      unreadCountProvider.overrideWith((_) async => 0),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const WardrobeScreen(),
    ),
  );
}

/// A fake [WardrobeNotifier] that immediately returns a pre-defined list of
/// items instead of calling the API.
class _FakeWardrobeNotifier extends AsyncNotifier<List<Item>>
    implements WardrobeNotifier {
  final List<Item> _items;
  _FakeWardrobeNotifier(this._items);

  @override
  Future<List<Item>> build() async => _items;

  @override
  Future<void> deleteItem(String id) async {}

  @override
  void refresh() {}
}

/// Creates a minimal [Item] for testing.
Item _makeItem(String id) => Item(
      id: id,
      imageUrl: 'https://example.com/$id.jpg',
      category: 'top',
      subCategory: 't-shirt',
      primaryColor: 'blue',
      createdAt: DateTime(2025, 3, 20),
    );

void main() {
  group('WardrobeScreen', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen());
      await tester.pumpAndSettle();
      expect(find.byType(WardrobeScreen), findsOneWidget);
    });

    testWidgets('displays the "Wardrobe" title', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen());
      await tester.pumpAndSettle();
      expect(find.text('Wardrobe'), findsOneWidget);
    });

    testWidgets('displays the search icon', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('displays the notification bell icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('displays category filter chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen());
      await tester.pumpAndSettle();

      // At minimum the "All" chip and a few specific categories should exist.
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Tops'), findsOneWidget);
      expect(find.text('Bottoms'), findsOneWidget);
    });

    testWidgets('displays the camera FAB with add icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows item count label when items are loaded',
        (WidgetTester tester) async {
      final items = List.generate(5, (i) => _makeItem('item-$i'));
      await tester.pumpWidget(_buildTestableWardrobeScreen(items: items));
      await tester.pumpAndSettle();

      expect(find.text('5 ITEMS'), findsOneWidget);
    });

    testWidgets('shows empty state when wardrobe has no items',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableWardrobeScreen(items: []));
      await tester.pumpAndSettle();

      expect(find.text('An empty closet.'), findsOneWidget);
      expect(find.text('Add an item'), findsOneWidget);
    });
  });
}
