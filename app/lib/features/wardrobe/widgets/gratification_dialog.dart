import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class GratificationDialog extends StatelessWidget {
  const GratificationDialog({super.key});

  static const _prefKey = 'gratification_shown';

  /// Returns `true` if the dialog has never been shown before.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  /// Marks the dialog as shown so it won't appear again.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Convenience: show the dialog and persist the flag.
  static Future<void> present(BuildContext context) async {
    await markShown();
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GratificationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.orangeSoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎉', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Three items added!',
              style: GoogleFonts.instrumentSerif(
                fontSize: 22,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You have enough for your first AI outfit. '
              'Ready to see what we can put together?',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/today');
                },
                child: Text('Generate Outfit',
                    style: AppTypography.button
                        .copyWith(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Keep Adding',
                    style: AppTypography.button
                        .copyWith(color: AppColors.ink2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
