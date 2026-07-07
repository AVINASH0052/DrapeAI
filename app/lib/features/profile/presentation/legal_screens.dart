import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    DrapeIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text('Privacy Policy',
                        style: AppTypography.headingSerif.copyWith(fontSize: 24)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [
                    _LegalSection(
                      title: 'What we collect',
                      body:
                          'Phone number or Google/Apple sign-in, wardrobe photos you upload, style quiz answers, outfit feedback (likes/dislikes), and push notification tokens if you opt in.',
                    ),
                    _LegalSection(
                      title: 'How we use AI',
                      body:
                          'Your clothing photos are sent to AI vision models (OpenAI and partners) for auto-tagging. Outfit suggestions use a rule engine plus LLM ranking. We never sell your images.',
                    ),
                    _LegalSection(
                      title: 'Storage',
                      body:
                          'Photos are stored on Cloudflare R2. Profile and wardrobe data live in encrypted PostgreSQL. Firebase handles authentication.',
                    ),
                    _LegalSection(
                      title: 'Your rights',
                      body:
                          'Delete your account anytime from Profile → Delete account. This removes all wardrobe items, outfits, and personal data within 30 days.',
                    ),
                    _LegalSection(
                      title: 'Contact',
                      body: 'privacy@drapeai.app',
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Last updated: July 2026',
                      style: TextStyle(color: AppColors.ink3, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    DrapeIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text('Terms of Service',
                        style: AppTypography.headingSerif.copyWith(fontSize: 24)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [
                    _LegalSection(
                      title: 'The deal',
                      body:
                          'DrapeAI is an AI styling assistant. We suggest outfits from your wardrobe — we are not liable for fashion choices at weddings, dates, or board meetings. 😄',
                    ),
                    _LegalSection(
                      title: 'Your content',
                      body:
                          'You own your wardrobe photos. By uploading, you grant us a license to process, tag, and display them back to you within the app.',
                    ),
                    _LegalSection(
                      title: 'Acceptable use',
                      body:
                          'No illegal content, harassment, or attempts to abuse AI systems. We may suspend accounts that violate these terms.',
                    ),
                    _LegalSection(
                      title: 'Subscriptions (future)',
                      body:
                          'Pro tier at ₹99/month when launched. Free tier: 50 items, 1 recommendation/day. Cancel anytime.',
                    ),
                    _LegalSection(
                      title: 'Disclaimer',
                      body:
                          'AI suggestions are probabilistic, not professional styling advice. Service provided "as is" without warranty.',
                    ),
                    _LegalSection(
                      title: 'Contact',
                      body: 'help@drapeai.app',
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Last updated: July 2026',
                      style: TextStyle(color: AppColors.ink3, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;

  const _LegalSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DrapeGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (_) =>
                  AppGradients.cta.createShader(const Rect.fromLTWH(0, 0, 200, 30)),
              child: Text(
                title,
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(body, style: AppTypography.body),
          ],
        ),
      ),
    );
  }
}
