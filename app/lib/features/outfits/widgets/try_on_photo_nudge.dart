import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../profile/providers/user_profile_provider.dart';

/// Dismissible banner nudging the user to add a full-body photo so
/// outfits can be visualized on them. Hidden once a photo exists or
/// after the user dismisses it.
class TryOnPhotoNudge extends ConsumerStatefulWidget {
  const TryOnPhotoNudge({super.key});

  static const _prefsKey = 'tryon_photo_nudge_dismissed';

  @override
  ConsumerState<TryOnPhotoNudge> createState() => _TryOnPhotoNudgeState();
}

class _TryOnPhotoNudgeState extends ConsumerState<TryOnPhotoNudge> {
  bool? _dismissed; // null = still loading prefs

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then(
      (prefs) {
        if (!mounted) return;
        setState(() {
          _dismissed = prefs.getBool(TryOnPhotoNudge._prefsKey) ?? false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _dismissed = false);
      },
    );
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TryOnPhotoNudge._prefsKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed != false) return const SizedBox.shrink();

    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null || profile.tryOnPhotoUrl != null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: DrapeGlassCard(
        gradientBorder: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: AppColors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'See outfits on you',
                    style: AppTypography.title.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add one full-body photo for AI previews of every fit.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/profile'),
              child: Text(
                'Add',
                style: AppTypography.title.copyWith(
                  fontSize: 14,
                  color: AppColors.orange,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
