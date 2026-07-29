import 'package:drapeai/core/constants/environment.dart';
import 'package:drapeai/features/avatar/presentation/avatar_studio_screen.dart';
import 'package:drapeai/features/avatar/providers/avatar_studio_provider.dart';
import 'package:drapeai/features/profile/providers/user_profile_provider.dart';
import 'package:drapeai/features/wardrobe/models/item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Item item(String id, String category, {String subCategory = ''}) => Item(
      id: id,
      imageUrl: '/uploads/$id.png',
      category: category,
      subCategory: subCategory,
      primaryColor: 'black',
      createdAt: DateTime(2026),
    );

void main() {
  test('dress and separates remain mutually exclusive', () {
    final notifier = AvatarStudioNotifier();
    notifier.toggleItem('dresses', item('dress', 'dress'));
    notifier.toggleItem('tops', item('top', 'top'));

    expect(notifier.state.selected.containsKey('dresses'), isFalse);
    expect(notifier.state.selected['tops']?.id, 'top');
  });

  test('compile-time developer entry is disabled by default', () {
    expect(Environment.enableDevTestFlow, isFalse);
  });

  testWidgets('empty slot guides the user to add the right garment',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          avatarWardrobeProvider.overrideWith((ref) async => const <Item>[]),
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'u1',
              displayName: 'Test',
              avatarStatus: 'ready',
            ),
          ),
        ],
        child: const MaterialApp(home: AvatarStudioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add tops to your closet'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Add bottoms to your closet'), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });
}
