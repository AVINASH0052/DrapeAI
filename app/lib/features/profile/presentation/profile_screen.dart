import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsOn = true;

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
                  Expanded(
                    child: Text('Profile',
                        style: GoogleFonts.instrumentSerif(
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          color: AppColors.ink,
                        )),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 18,
                          color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Avatar + name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.orangeSoft, AppColors.pinkSoft],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text('A',
                          style: GoogleFonts.instrumentSerif(
                            fontSize: 28, color: AppColors.ink)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Avinash',
                            style: GoogleFonts.instrumentSerif(
                              fontSize: 24, color: AppColors.ink, height: 1)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.orangeSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Free',
                                  style: AppTypography.mono.copyWith(
                                      color: AppColors.orange,
                                      fontSize: 10.5)),
                            ),
                            const SizedBox(width: 8),
                            Text('· member since Mar 2026',
                                style: AppTypography.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Style profile
            _SectionHead('Style profile'),
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
                  children: [
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: ['Men', 'Minimalist', 'Classic', 'Casual',
                          'Neutrals', 'Regular', 'Mumbai']
                          .map((c) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1EFEB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(c,
                                    style: AppTypography.chip
                                        .copyWith(fontSize: 11)),
                              ))
                          .toList(),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Want different suggestions?',
                            style: AppTypography.caption),
                        GestureDetector(
                          onTap: () => context.push('/onboarding'),
                          child: Text('Retake quiz',
                              style: AppTypography.label.copyWith(
                                  color: AppColors.orange, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Wardrobe stats
            _SectionHead('Wardrobe'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: const [
                    _StatBlock(value: '24', label: 'Items'),
                    _StatBlock(value: '18', label: 'Saved'),
                    _StatBlock(value: '73%', label: 'In rotation'),
                  ],
                ),
              ),
            ),

            // AI Insights
            _SectionHead('AI insights'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => context.pushNamed('wardrobe_gaps'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.orangeSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome,
                            size: 22, color: AppColors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('What should I buy next?',
                                style: AppTypography.label.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                            Text(
                                'AI-curated wardrobe gap analysis',
                                style: AppTypography.caption),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.ink3),
                    ],
                  ),
                ),
              ),
            ),

            // Preferences
            _SectionHead('Preferences'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _SettingRow(
                      label: 'Morning outfit notification',
                      trailing: GestureDetector(
                        onTap: () =>
                            setState(() => _notificationsOn = !_notificationsOn),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 46, height: 28,
                          decoration: BoxDecoration(
                            color: _notificationsOn
                                ? AppColors.orange
                                : AppColors.borderStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: _notificationsOn
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 24, height: 24,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _SettingRow(
                      label: 'Appearance',
                      trailing: Text('Light',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.ink2)),
                    ),
                    _SettingRow(
                      label: 'About drape.ai',
                      trailing: const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.ink3),
                      last: true,
                    ),
                  ],
                ),
              ),
            ),

            // Help & legal
            _SectionHead('Help & legal'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: const [
                    _SettingRow(
                      label: 'Terms & Privacy',
                      trailing: Icon(Icons.chevron_right,
                          size: 16, color: AppColors.ink3),
                    ),
                    _SettingRow(
                      label: 'Help & feedback',
                      trailing: Icon(Icons.chevron_right,
                          size: 16, color: AppColors.ink3),
                      last: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            // Sign out / Delete
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: TextButton(
                      onPressed: () {
                        ref.read(authStatusProvider.notifier).logout();
                        context.go('/login');
                      },
                      child: Text('Sign out',
                          style: AppTypography.button
                              .copyWith(color: AppColors.ink2)),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: TextButton(
                      onPressed: () {},
                      child: Text('Delete account',
                          style: AppTypography.button
                              .copyWith(color: AppColors.red)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('drape.ai · v1.0.0',
                  style: AppTypography.mono.copyWith(
                      fontSize: 10, color: AppColors.ink3.withValues(alpha: 0.5))),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String text;
  const _SectionHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(text.toUpperCase(),
          style: AppTypography.mono.copyWith(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.ink2, letterSpacing: 0.8)),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.instrumentSerif(
                fontSize: 28, color: AppColors.ink, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final bool last;

  const _SettingRow({
    required this.label,
    required this.trailing,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.label.copyWith(fontSize: 14)),
          trailing,
        ],
      ),
    );
  }
}
