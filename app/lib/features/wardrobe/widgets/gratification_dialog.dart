import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';

class GratificationDialog extends StatelessWidget {
  const GratificationDialog({super.key});

  static const _prefKey = 'gratification_shown';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  static Future<void> present(BuildContext context) async {
    await markShown();
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const GratificationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DrapeGlassCard(
        gradientBorder: true,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              '3 pieces. let\'s cook.',
              style: GoogleFonts.syne(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your closet has enough for your first AI fit. Ready to see the magic?',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 24),
            DrapeGradientButton(
              label: 'Show me fits ✨',
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/today');
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('keep adding', style: AppTypography.caption),
            ),
          ],
        ),
      ),
    );
  }
}
