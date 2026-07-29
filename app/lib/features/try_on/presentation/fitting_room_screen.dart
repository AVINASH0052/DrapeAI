import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/brand/brand.dart';
import '../../../core/constants/environment.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../services/try_on_photo_actions.dart';

/// Single hub: body photo + wardrobe try-on cue + shop photo + history.
class FittingRoomScreen extends ConsumerStatefulWidget {
  const FittingRoomScreen({super.key});

  @override
  ConsumerState<FittingRoomScreen> createState() => _FittingRoomScreenState();
}

class _FittingRoomScreenState extends ConsumerState<FittingRoomScreen> {
  bool _busy = false;

  Future<void> _addPhoto() async {
    setState(() => _busy = true);
    try {
      await uploadTryOnPhotoInPlace(ref, context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    try {
      await deleteTryOnPhotoInPlace(ref, context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                title: 'Fitting Room',
                subtitle: 'see looks on you · ${Brand.name}',
                gradientTitle: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'One full-body photo. Then try wardrobe fits or any shop screenshot.',
                  style: AppTypography.caption,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: profileAsync.when(
                  loading: () => const DrapeGlassCard(
                    child: SizedBox(
                      height: 88,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, __) => DrapeGlassCard(
                    child: Text(
                      'Could not load your photo',
                      style: AppTypography.caption,
                    ),
                  ),
                  data: (profile) {
                    final url = profile.tryOnPhotoUrl;
                    return DrapeGlassCard(
                      gradientBorder: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: url == null
                                ? Container(
                                    width: 72,
                                    height: 96,
                                    color: AppColors.orange.withValues(alpha: 0.12),
                                    child: const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.orange,
                                    ),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: Environment.resolveUrl(url),
                                    width: 72,
                                    height: 96,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  url == null
                                      ? 'Add your body photo'
                                      : 'Your try-on photo',
                                  style: AppTypography.title.copyWith(fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  url == null
                                      ? 'Plain light background, head to toe, standing straight.'
                                      : 'Used for wardrobe previews and shop screenshots.',
                                  style: AppTypography.caption,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Flexible(
                                      child: DrapeGradientButton(
                                        label: url == null
                                            ? 'Add photo'
                                            : 'Update',
                                        onPressed: _busy ? null : _addPhoto,
                                      ),
                                    ),
                                    if (url != null) ...[
                                      const SizedBox(width: 8),
                                      DrapeIconButton(
                                        icon: Icons.delete_outline_rounded,
                                        onTap: _busy ? () {} : _removePhoto,
                                      ),
                                    ],
                                  ],
                                ),
                                if (_busy)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: LinearProgressIndicator(
                                      color: AppColors.orange,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const DrapeSectionLabel('Try something on'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    DrapeGlassCard(
                      gradientBorder: true,
                      onTap: () => context.go('/today'),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.checkroom_rounded,
                              color: AppColors.orange,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wardrobe outfit',
                                  style:
                                      AppTypography.title.copyWith(fontSize: 15),
                                ),
                                Text(
                                  'Open Fit → tap “See me in this” on a look',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DrapeGlassCard(
                      gradientBorder: true,
                      onTap: () => context.push('/fitting-room/shop'),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.pinkSoft.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shop / screenshot',
                                  style:
                                      AppTypography.title.copyWith(fontSize: 15),
                                ),
                                Text(
                                  'Catalog photo or Myntra/Ajio screenshot',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const DrapeSectionLabel('Your looks'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DrapeGlassCard(
                  onTap: () => context.push('/fitting-room/history'),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppColors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Shop try-on history',
                          style: AppTypography.title.copyWith(fontSize: 15),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted(context),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: DrapeGlassCard(
                  onTap: () => context.push('/lookbooks'),
                  child: Row(
                    children: [
                      const Text('📌', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mood boards',
                              style: AppTypography.title.copyWith(fontSize: 15),
                            ),
                            Text(
                              'Saved lookbooks (moved here from the tab bar)',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
