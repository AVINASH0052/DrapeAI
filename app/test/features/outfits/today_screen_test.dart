import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:drapeai/core/theme/app_theme.dart';
import 'package:drapeai/features/outfits/presentation/today_screen.dart';
import 'package:drapeai/features/outfits/providers/today_provider.dart';
import 'package:drapeai/features/outfits/providers/weather_provider.dart';
import 'package:drapeai/features/outfits/models/outfit_model.dart';
import 'package:drapeai/features/profile/providers/user_profile_provider.dart';

/// Helper that wraps [TodayScreen] with overridden providers.
Widget _buildTestableTodayScreen({
  List<Outfit> outfits = const [],
  UserProfile? profile,
}) {
  return ProviderScope(
    overrides: [
      // Override outfits with a static list.
      todayOutfitsProvider.overrideWith((_) async => outfits),
      // Override weather so it doesn't call the API.
      weatherProvider.overrideWith(
        (_) async => WeatherInfo(city: 'Mumbai', condition: 'Sunny', tempC: 32),
      ),
      if (profile != null)
        userProfileProvider.overrideWith((_) async => profile),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const TodayScreen(),
    ),
  );
}

void main() {
  group('TodayScreen', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('displays the screen title', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.text("Today's Fit"), findsOneWidget);
    });

    testWidgets('displays weather information', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.text('🌡 Mumbai · Sunny, 32°'), findsOneWidget);
    });

    testWidgets('displays occasion chips', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();

      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Party'), findsOneWidget);
      expect(find.text('Festive ✨'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('displays the shuffle icon', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    });

    testWidgets('shows empty state with generate button when no outfits',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen(outfits: []));
      await tester.pumpAndSettle();

      // The empty state displays "Nothing yet for casual." (default occasion).
      expect(find.textContaining('no casual fits yet'), findsOneWidget);
      expect(find.text('Generate fits'), findsOneWidget);
    });

    testWidgets('generate button is present in empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen(outfits: []));
      await tester.pumpAndSettle();

      expect(find.text('Generate fits'), findsOneWidget);
    });
  });

  group('TryOnPhotoNudge', () {
    const profileNoPhoto = UserProfile(
      id: 'u1',
      displayName: 'Test User',
    );
    const profileWithPhoto = UserProfile(
      id: 'u1',
      displayName: 'Test User',
      tryOnPhotoUrl: 'https://example.com/photo.jpg',
    );

    testWidgets('shows nudge when user has no try-on photo',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester
          .pumpWidget(_buildTestableTodayScreen(profile: profileNoPhoto));
      await tester.pumpAndSettle();

      expect(find.text('See outfits on you'), findsOneWidget);
    });

    testWidgets('hides nudge when user already has a try-on photo',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester
          .pumpWidget(_buildTestableTodayScreen(profile: profileWithPhoto));
      await tester.pumpAndSettle();

      expect(find.text('See outfits on you'), findsNothing);
    });

    testWidgets('dismissing the nudge hides it and persists',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester
          .pumpWidget(_buildTestableTodayScreen(profile: profileNoPhoto));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('See outfits on you'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tryon_photo_nudge_dismissed'), isTrue);
    });

    testWidgets('stays hidden when previously dismissed',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(
          {'tryon_photo_nudge_dismissed': true});
      await tester
          .pumpWidget(_buildTestableTodayScreen(profile: profileNoPhoto));
      await tester.pumpAndSettle();

      expect(find.text('See outfits on you'), findsNothing);
    });
  });
}
