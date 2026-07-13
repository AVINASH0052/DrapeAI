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
    testWidgets("renders with the title '3 pieces. let's cook.'",
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text("3 pieces. let's cook."), findsOneWidget);
    });

    testWidgets('displays the celebration emoji', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('displays body text explaining outfit generation',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your closet has enough for your first AI fit'),
        findsOneWidget,
      );
    });

    testWidgets('displays the "Show me fits" button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(find.text('Show me fits \u2728'), findsOneWidget);
    });

    testWidgets('displays the "keep adding" button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextButton, 'keep adding'),
        findsOneWidget,
      );
    });

    testWidgets('"keep adding" button closes the dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestableDialog());
      await tester.pumpAndSettle();

      // Tap "Keep Adding" and wait for the dialog to close.
      await tester.tap(find.text('keep adding'));
      await tester.pumpAndSettle();

      expect(find.text("3 pieces. let's cook."), findsNothing);
    });
  });
}
