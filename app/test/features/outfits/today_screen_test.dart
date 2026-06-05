import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drapeai/core/theme/app_theme.dart';
import 'package:drapeai/features/outfits/presentation/today_screen.dart';
import 'package:drapeai/features/outfits/providers/today_provider.dart';
import 'package:drapeai/features/outfits/providers/weather_provider.dart';
import 'package:drapeai/features/outfits/models/outfit_model.dart';

/// Helper that wraps [TodayScreen] with overridden providers.
Widget _buildTestableTodayScreen({List<Outfit> outfits = const []}) {
  return ProviderScope(
    overrides: [
      // Override outfits with a static list.
      todayOutfitsProvider.overrideWith((_) async => outfits),
      // Override weather so it doesn't call the API.
      weatherProvider.overrideWith(
        (_) async => WeatherInfo(city: 'Mumbai', condition: 'Sunny', tempC: 32),
      ),
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

    testWidgets('displays the "Today" title', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('displays weather information', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.text('Mumbai · Sunny, 32°'), findsOneWidget);
    });

    testWidgets('displays occasion chips', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();

      expect(find.text('Casual'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Party'), findsOneWidget);
      expect(find.text('Festive'), findsOneWidget);
      expect(find.text('Date Night'), findsOneWidget);
    });

    testWidgets('displays the shuffle icon', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
    });

    testWidgets('shows empty state with generate button when no outfits',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen(outfits: []));
      await tester.pumpAndSettle();

      // The empty state displays "Nothing yet for casual." (default occasion).
      expect(find.textContaining('Nothing yet for'), findsOneWidget);
      expect(find.text('Generate outfits'), findsOneWidget);
    });

    testWidgets('generate button is an ElevatedButton',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableTodayScreen(outfits: []));
      await tester.pumpAndSettle();

      final generateButton = find.widgetWithText(ElevatedButton, 'Generate outfits');
      expect(generateButton, findsOneWidget);
    });
  });
}
