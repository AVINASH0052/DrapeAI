import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/brand/brand.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

import '../../../core/widgets/drape_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 28),
            children: [
              DrapeScreenHeader(
                title: 'About',
                subtitle: '${Brand.name} · ${Brand.tagline}',
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.orangeSoft, AppColors.pinkSoft],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          'A',
                          style: GoogleFonts.instrumentSerif(
                            fontSize: 32,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      Brand.name,
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 28,
                        color: AppColors.ink,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'v1.0.0',
                      style: AppTypography.mono
                          .copyWith(fontSize: 12, color: AppColors.ink3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _section('What is ${Brand.name}?'),
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
                    '${Brand.name} is your AI-powered personal stylist. '
                    'Snap photos of your clothes, and our engine builds '
                    'outfits tailored to your style, body, weather, and '
                    'occasion — every single morning.',
                    style: AppTypography.body.copyWith(height: 1.55),
                  ),
                ),
              ),
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
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.mono.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.ink2,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _techRow(String name, String desc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(name, style: AppTypography.label.copyWith(fontSize: 14)),
        Text(
          desc,
          style: AppTypography.caption.copyWith(color: AppColors.ink2),
        ),
      ],
    );
  }
}
