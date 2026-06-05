import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drapeai/core/theme/app_theme.dart';
import 'package:drapeai/features/wardrobe/widgets/gratification_dialog.dart';

/// Helper that renders the [GratificationDialog] inside a dialog context.
/// We use a Scaffold + Builder so we can call `showDialog` in a realistic
/// widget tree.
Widget _buildTestableDialog() {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          // Schedule the dialog to show after the first frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const GratificationDialog(),
            );
          });
          return const SizedBox.shrink();
        },
      ),
    ),
  );
}

void main() {
  group('GratificationDialog', () {
    testWidgets('renders with the title "Three items added!"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text('Three items added!'), findsOneWidget);
    });

    testWidgets('displays the celebration emoji', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text('🎉'), findsOneWidget);
    });

    testWidgets('displays body text explaining outfit generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('You have enough for your first AI outfit'),
        findsOneWidget,
      );
    });

    testWidgets('displays the "Generate Outfit" button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text('Generate Outfit'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Generate Outfit'),
        findsOneWidget,
      );
    });

    testWidgets('displays the "Keep Adding" button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text('Keep Adding'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Keep Adding'),
        findsOneWidget,
      );
    });

    testWidgets('"Keep Adding" button closes the dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      // Tap "Keep Adding" and wait for the dialog to close.
      await tester.tap(find.text('Keep Adding'));
      await tester.pumpAndSettle();

      expect(find.text('Three items added!'), findsNothing);
    });
  });
}
