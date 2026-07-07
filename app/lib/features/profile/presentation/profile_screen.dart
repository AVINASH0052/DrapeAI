import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

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
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_stats_provider.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/edit_profile_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsOn = false;
  bool _deletingAccount = false;
  bool _uploadingTryOn = false;

  static const _notifPrefKey = 'push_notifications_enabled';

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _notificationsOn = prefs.getBool(_notifPrefKey) ?? false);
    }
  }

  Future<void> _openEditProfile(String name) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(currentName: name),
    );
    if (result == true) {
      ref.invalidate(profileStatsProvider);
      ref.invalidate(userProfileProvider);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete your account?',
            style: AppTypography.headingSerif.copyWith(fontSize: 22)),
        content: Text(
          'All wardrobe items, outfits, and data will be permanently removed.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTypography.button),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: AppTypography.button.copyWith(color: AppColors.red)),
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
          const SnackBar(
            content: Text('Please sign in again before deleting your account.'),
            backgroundColor: AppColors.red,
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
          ),
        );
        return;
      }

      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifPrefKey, value);
    if (mounted) setState(() => _notificationsOn = value);

    if (value) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();
        final token = await messaging.getToken();
        if (token != null) {
          final platform = Platform.isIOS ? 'ios' : 'android';
          await ref.read(apiClientProvider).registerPushToken(token, platform);
        }
      } catch (_) {}
    } else {
      try {
        await ref.read(apiClientProvider).unregisterPushToken();
      } catch (_) {}
    }
  }

  Future<void> _uploadTryOnPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingTryOn = true);
    try {
      await ref.read(apiClientProvider).uploadTryOnPhoto(picked.path);
      ref.invalidate(userProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full-body photo saved — try "See me in this fit" on any outfit'),
            backgroundColor: AppColors.lime,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingTryOn = false);
    }
  }

  Future<void> _removeTryOnPhoto() async {
    setState(() => _uploadingTryOn = true);
    try {
      await ref.read(apiClientProvider).deleteTryOnPhoto();
      ref.invalidate(userProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingTryOn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(profileStatsProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 100),
            children: [
              DrapeScreenHeader(
                title: 'You',
                subtitle: 'your style DNA',
                gradientTitle: true,
                actions: [
                  profileAsync.whenOrNull(
                        data: (p) => DrapeIconButton(
                          icon: Icons.edit_outlined,
                          onTap: () => _openEditProfile(p.displayName),
                        ),
                      ) ??
                      DrapeIconButton(
                        icon: Icons.edit_outlined,
                        onTap: () => _openEditProfile(''),
                      ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: profileAsync.when(
                  loading: () => _buildAvatarShimmer(),
                  error: (_, __) => _buildAvatar('?', 'Stylist', ''),
                  data: (profile) => _buildAvatar(
                    profile.initials,
                    profile.displayName,
                    profile.memberSince,
                  ),
                ),
              ),
              const DrapeSectionLabel('Style profile'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DrapeGlassCard(
                  child: profileAsync.when(
                    loading: () => const SizedBox(height: 40),
                    error: (_, __) => const Text('Could not load style profile'),
                    data: (profile) => Column(
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: (profile.styleTags.isEmpty
                                  ? ['Take the style quiz →']
                                  : profile.styleTags)
                              .map((c) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: profile.styleTags.isEmpty
                                          ? null
                                          : AppGradients.cta,
                                      color: profile.styleTags.isEmpty
                                          ? AppColors.gray100
                                          : null,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      c,
                                      style: AppTypography.chip.copyWith(
                                        fontSize: 11,
                                        color: profile.styleTags.isEmpty
                                            ? AppColors.ink3
                                            : Colors.white,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('vibe check?', style: AppTypography.caption),
                            GestureDetector(
                              onTap: () => context.push('/onboarding'),
                              child: Text(
                                'Retake quiz',
                                style: AppTypography.label
                                    .copyWith(color: AppColors.orange),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const DrapeSectionLabel('Wardrobe'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DrapeGlassCard(
                  child: statsAsync.when(
                    loading: () => Row(
                      children: List.generate(
                        3,
                        (_) => Expanded(child: _statShimmer()),
                      ),
                    ),
                    error: (_, __) => const Row(
                      children: [
                        _StatBlock(value: '—', label: 'Pieces'),
                        _StatBlock(value: '—', label: 'Saved'),
                        _StatBlock(value: '—', label: 'Rotation'),
                      ],
                    ),
                    data: (stats) => Row(
                      children: [
                        _StatBlock(
                            value: '${stats.totalItems}', label: 'Pieces'),
                        _StatBlock(
                            value: '${stats.savedOutfits}', label: 'Saved'),
                        _StatBlock(
                            value: '${stats.utilizationPct}%',
                            label: 'Rotation'),
                      ],
                    ),
                  ),
                ),
              ),
              const DrapeSectionLabel('See me in outfits'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: profileAsync.when(
                  loading: () => const DrapeGlassCard(
                    child: SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (profile) => DrapeGlassCard(
                    gradientBorder: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your wardrobe stylist — not a shop',
                          style: AppTypography.title.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Add a full-body photo once. We\'ll composite outfits from clothes you already own.',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 14),
                        if (profile.tryOnPhotoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: CachedNetworkImage(
                                imageUrl: Environment.resolveUrl(
                                    profile.tryOnPhotoUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DrapeGradientButton(
                                label: profile.tryOnPhotoUrl != null
                                    ? 'Update photo'
                                    : 'Add full-body photo',
                                onPressed:
                                    _uploadingTryOn ? null : _uploadTryOnPhoto,
                              ),
                            ),
                            if (profile.tryOnPhotoUrl != null) ...[
                              const SizedBox(width: 10),
                              DrapeIconButton(
                                icon: Icons.delete_outline_rounded,
                                onTap: _uploadingTryOn
                                    ? () {}
                                    : _removeTryOnPhoto,
                              ),
                            ],
                          ],
                        ),
                        if (_uploadingTryOn)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                              color: AppColors.orange,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const DrapeSectionLabel('Wardrobe insights'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DrapeGlassCard(
                  gradientBorder: true,
                  onTap: () => context.pushNamed('wardrobe_gaps'),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppGradients.cta,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('What\'s missing?',
                                style: AppTypography.title.copyWith(fontSize: 16)),
                            Text('Gaps in your closet — wardrobe only',
                                style: AppTypography.caption),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted(context)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DrapeGlassCard(
                        onTap: () => context.pushNamed('calendar'),
                        padding: const EdgeInsets.all(14),
                        child: const Column(
                          children: [
                            Text('📅', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 6),
                            Text('Calendar', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DrapeGlassCard(
                        onTap: () => context.pushNamed('analytics'),
                        padding: const EdgeInsets.all(14),
                        child: const Column(
                          children: [
                            Text('📊', style: TextStyle(fontSize: 24)),
                            SizedBox(height: 6),
                            Text('Stats', style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const DrapeSectionLabel('Preferences'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DrapeGlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingRow(
                        label: 'Morning fit notification',
                        trailing: _NotifToggle(
                          on: _notificationsOn,
                          onChanged: _toggleNotifications,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            ref.read(themeModeProvider.notifier).cycle(),
                        child: _SettingRow(
                          label: 'Appearance',
                          trailing: Text(
                            switch (ref.watch(themeModeProvider)) {
                              ThemeMode.light => 'Light ☀️',
                              ThemeMode.dark => 'Dark 🌙',
                              ThemeMode.system => 'Auto',
                            },
                            style: AppTypography.caption,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/about'),
                        child: const _SettingRow(
                          label: 'About drape.ai',
                          trailing: Icon(Icons.chevron_right_rounded, size: 18),
                          last: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const DrapeSectionLabel('Help & legal'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DrapeGlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: const _SettingRow(
                          label: 'Privacy Policy',
                          trailing: Icon(Icons.chevron_right_rounded, size: 18),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/terms'),
                        child: const _SettingRow(
                          label: 'Terms of Service',
                          trailing: Icon(Icons.chevron_right_rounded, size: 18),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('mailto:help@drapeai.app'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const _SettingRow(
                          label: 'Help & feedback',
                          trailing: Icon(Icons.chevron_right_rounded, size: 18),
                          last: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        ref.read(authStatusProvider.notifier).logout();
                        context.go('/login');
                      },
                      child: const Text('Sign out'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _deletingAccount ? null : _deleteAccount,
                      child: _deletingAccount
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Delete account',
                              style: AppTypography.button
                                  .copyWith(color: AppColors.red),
                            ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Text(
                  'drape.ai · v1.0.0',
                  style: AppTypography.mono.copyWith(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String initials, String name, String memberSince) {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.hero,
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface(context),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.syne(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTypography.headingSerif.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppGradients.cta,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'FREE',
                      style: AppTypography.mono.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (memberSince.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(memberSince, style: AppTypography.caption),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.bgWarm,
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 120, height: 24, color: AppColors.card),
              const SizedBox(height: 8),
              Container(width: 80, height: 14, color: AppColors.card),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.bgWarm,
      child: Column(
        children: [
          Container(width: 36, height: 28, color: AppColors.card),
          const SizedBox(height: 6),
          Container(width: 48, height: 12, color: AppColors.card),
        ],
      ),
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
          ShaderMask(
            shaderCallback: (_) =>
                AppGradients.cta.createShader(const Rect.fromLTWH(0, 0, 60, 40)),
            child: Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
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
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColorsDark.border
                      : AppColors.border,
                ),
              ),
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

class _NotifToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;

  const _NotifToggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          gradient: on ? AppGradients.cta : null,
          color: on ? null : AppColors.borderStrong,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
