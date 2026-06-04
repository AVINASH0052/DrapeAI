import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 28),
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 18, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('About',
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        color: AppColors.ink,
                      )),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logo / brand
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.orangeSoft, AppColors.pinkSoft],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text('D',
                          style: GoogleFonts.instrumentSerif(
                              fontSize: 32, color: AppColors.ink)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('drape.ai',
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 28, color: AppColors.ink, height: 1)),
                  const SizedBox(height: 6),
                  Text('v1.0.0',
                      style: AppTypography.mono
                          .copyWith(fontSize: 12, color: AppColors.ink3)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Description card
            _section('What is drape.ai?'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'drape.ai is your AI-powered personal stylist. '
                  'Snap photos of your clothes, and our engine builds '
                  'outfits tailored to your style, body, weather, and '
                  'occasion — every single morning.',
                  style: AppTypography.body.copyWith(height: 1.55),
                ),
              ),
            ),

            // Built with
            _section('Built with'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _techRow('Flutter & Dart', 'Cross-platform UI'),
                    const Divider(height: 20, color: AppColors.border),
                    _techRow('Firebase', 'Auth & messaging'),
                    const Divider(height: 20, color: AppColors.border),
                    _techRow('Python + FastAPI', 'AI styling engine'),
                    const Divider(height: 20, color: AppColors.border),
                    _techRow('Gemini', 'Vision & language models'),
                  ],
                ),
              ),
            ),

            // Acknowledgements
            _section('Acknowledgements'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Designed and developed by Avinash. '
                  'Special thanks to the Flutter, Riverpod, and '
                  'Firebase open-source communities.',
                  style: AppTypography.body.copyWith(height: 1.55),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(text.toUpperCase(),
          style: AppTypography.mono.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink2,
              letterSpacing: 0.8)),
    );
  }

  Widget _techRow(String name, String desc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name,
            style: AppTypography.label.copyWith(fontSize: 14)),
        Text(desc,
            style: AppTypography.caption
                .copyWith(color: AppColors.ink2)),
      ],
    );
  }
}
