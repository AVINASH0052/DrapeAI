import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sugatai/core/theme/app_theme.dart';
import 'package:sugatai/features/notifications/presentation/notifications_screen.dart';
import 'package:sugatai/features/notifications/providers/notifications_provider.dart';

/// Helper that wraps [NotificationsScreen] with overridden providers.
Widget _buildTestableNotificationsScreen({
  List<Map<String, dynamic>> notifications = const [],
  int unreadCount = 0,
}) {
  return ProviderScope(
    overrides: [
      notificationsProvider.overrideWith((_) async => notifications),
      unreadCountProvider.overrideWith((_) async => unreadCount),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const NotificationsScreen(),
    ),
  );
}

void main() {
  group('NotificationsScreen', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableNotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('displays the "Notifications" title in the AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableNotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('displays "Mark all read" action button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableNotificationsScreen());
      await tester.pumpAndSettle();
      expect(find.text('Mark all read'), findsOneWidget);
    });

    testWidgets('shows empty state icon when there are no notifications',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableNotificationsScreen(notifications: []),
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.notifications_none_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows "No notifications yet" message in empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestableNotificationsScreen(notifications: []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.textContaining('outfit'),
        findsOneWidget,
      );
    });

    testWidgets('renders notification tiles when data is present',
        (WidgetTester tester) async {
      final mockNotifications = [
        {
          'id': 'n1',
          'title': 'New outfit ready!',
          'body': 'Your casual outfit for today has been generated.',
          'type': 'outfit',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'n2',
          'title': 'Welcome to Sugatai',
          'body': 'Start adding items to your wardrobe.',
          'type': 'system',
          'is_read': true,
          'created_at':
              DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        },
      ];

      await tester.pumpWidget(
        _buildTestableNotificationsScreen(
          notifications: mockNotifications,
          unreadCount: 1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New outfit ready!'), findsOneWidget);
      expect(find.text('Welcome to Sugatai'), findsOneWidget);
    });
  });
}
