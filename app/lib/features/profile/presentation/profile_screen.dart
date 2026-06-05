import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_stats_provider.dart';
import '../widgets/edit_profile_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsOn = false;
  bool _deletingAccount = false;

  static const _notifPrefKey = 'push_notifications_enabled';

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsOn = prefs.getBool(_notifPrefKey) ?? false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const EditProfileSheet(currentName: 'Avinash'),
    );
    if (result == true) {
      ref.invalidate(profileStatsProvider);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text('Delete your account?',
            style: GoogleFonts.instrumentSerif(
              fontSize: 20, color: AppColors.ink)),
        content: Text(
          'This cannot be undone. All your wardrobe items, '
          'outfits, and data will be permanently removed.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: AppTypography.button
                    .copyWith(color: AppColors.ink2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style:
                    AppTypography.button.copyWith(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      final result =
          await ref.read(authStatusProvider.notifier).deleteAccount();
      if (!mounted) return;

      if (result == 'requires-recent-login') {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Please sign in again before deleting your account.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      if (result != null) {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $result'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Success
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(profileStatsProvider);

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
                    onTap: _openEditProfile,
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

            // Wardrobe stats — live from API
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
                child: statsAsync.when(
                  loading: () => Row(
                    children: List.generate(3, (_) => Expanded(
                      child: Shimmer.fromColors(
                        baseColor: AppColors.border,
                        highlightColor: AppColors.bgWarm,
                        child: Column(
                          children: [
                            Container(
                              width: 36, height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 48, height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                  error: (_, __) => Row(
                    children: const [
                      _StatBlock(value: '—', label: 'Items'),
                      _StatBlock(value: '—', label: 'Saved'),
                      _StatBlock(value: '—', label: 'In rotation'),
                    ],
                  ),
                  data: (stats) => Row(
                    children: [
                      _StatBlock(
                          value: '${stats.totalItems}', label: 'Items'),
                      _StatBlock(
                          value: '${stats.savedOutfits}', label: 'Saved'),
                      _StatBlock(
                          value: '${stats.utilizationPct}%',
                          label: 'In rotation'),
                    ],
                  ),
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
                        onTap: () => _toggleNotifications(!_notificationsOn),
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
                    GestureDetector(
                      onTap: () => ref.read(themeModeProvider.notifier).cycle(),
                      child: _SettingRow(
                        label: 'Appearance',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              switch (ref.watch(themeModeProvider)) {
                                ThemeMode.light => 'Light',
                                ThemeMode.dark => 'Dark',
                                ThemeMode.system => 'System',
                              },
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.ink2),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 14, color: AppColors.ink3),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/about'),
                      child: _SettingRow(
                        label: 'About drape.ai',
                        trailing: const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.ink3),
                        last: true,
                      ),
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
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _launchUrl('https://drapeai.app/terms'),
                      child: const _SettingRow(
                        label: 'Terms & Privacy',
                        trailing: Icon(Icons.chevron_right,
                            size: 16, color: AppColors.ink3),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          _launchUrl('mailto:help@drapeai.app'),
                      child: const _SettingRow(
                        label: 'Help & feedback',
                        trailing: Icon(Icons.chevron_right,
                            size: 16, color: AppColors.ink3),
                        last: true,
                      ),
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
                      onPressed: _deletingAccount ? null : _deleteAccount,
                      child: _deletingAccount
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.red),
                            )
                          : Text('Delete account',
                              style: AppTypography.button
                                  .copyWith(color: AppColors.red)),
                    ),
                  ),
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
