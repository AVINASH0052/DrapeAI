import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/drape_ui.dart';
import '../providers/today_provider.dart';
import '../providers/weather_provider.dart';
import '../widgets/outfit_card.dart';
import '../widgets/try_on_photo_nudge.dart';
import '../../wardrobe/models/item_model.dart';
import '../../wardrobe/providers/wardrobe_provider.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _generating = false;

  static const _occasions = [
    ('casual', 'Casual'),
    ('work', 'Work'),
    ('party', 'Party'),
    ('festive', 'Festive'),
    ('date', 'Date'),
  ];

  Future<void> _generate(String occasion) async {
    setState(() => _generating = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.generateOutfits(occasion);
      ref.invalidate(todayOutfitsProvider);
    } catch (e) {
      if (mounted) {
        final detail = e is DioException && e.response?.data is Map
            ? (e.response?.data as Map)['detail']?.toString()
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(detail ?? 'Could not generate fits. Please try again.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfitsAsync = ref.watch(todayOutfitsProvider);
    final occasion = ref.watch(selectedOccasionProvider);
    final wardrobe = ref.watch(wardrobeProvider).valueOrNull ?? const <Item>[];

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DrapeScreenHeader(
                title: 'Today\'s Fit',
                subtitle: null,
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.shuffle_rounded,
                    onTap: () => context.pushNamed('shuffle'),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _WeatherLine(),
              ),
              const TryOnPhotoNudge(),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _occasions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (key, label) = _occasions[i];
                    final isActive = occasion == key;
                    return DrapeChip(
                      label: label,
                      active: isActive,
                      onTap: () => ref
                          .read(selectedOccasionProvider.notifier)
                          .state = key,
                    );
                  },
                ),
              ),
              Expanded(
                child: outfitsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.orange),
                  ),
                  error: (e, _) => Center(
                    child: DrapeGlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 36,
                            color: AppColors.orange,
                          ),
                          const SizedBox(height: 12),
                          Text('fits didn\'t load', style: AppTypography.title),
                          const SizedBox(height: 12),
                          DrapeGradientButton(
                            label: 'Retry',
                            onPressed: () =>
                                ref.invalidate(todayOutfitsProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (outfits) => outfits.isEmpty
                      ? _buildEmpty(occasion, wardrobe)
                      : RefreshIndicator(
                          color: AppColors.orange,
                          onRefresh: () async => _generate(occasion),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            itemCount: outfits.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, i) =>
                                TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 300 + i * 100),
                              builder: (_, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 16 * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: OutfitCard(outfit: outfits[i]),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String occasion, List<Item> wardrobe) {
    final ready =
        wardrobe.where((item) => !item.isProcessing && !item.isFailed);
    final hasTop = ready.any(
      (item) =>
          item.category == 'top' ||
          item.category == 'ethnic' ||
          {'kurta', 'shirt', 't-shirt'}.contains(item.subCategory),
    );
    final hasBottom = ready.any((item) => item.category == 'bottom');
    final hasStandalone = ready.any(
      (item) =>
          item.category == 'dress' ||
          (item.category == 'ethnic' &&
              {'saree', 'lehenga', 'sherwani', 'anarkali'}
                  .contains(item.subCategory)),
    );
    final canGenerate = hasStandalone || (hasTop && hasBottom);
    final missingLabel = !hasTop
        ? 'Add a top'
        : !hasBottom && !hasStandalone
            ? 'Add a bottom'
            : 'Generate fits';
    final helper = canGenerate
        ? 'AI picks a complete look from your closet.'
        : 'Add a matching ${!hasTop ? 'top' : 'bottom'} to build a complete look.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: DrapeGlassCard(
          gradientBorder: true,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 40,
                color: AppColors.orange,
              ),
              const SizedBox(height: 12),
              Text(
                'no $occasion fits yet',
                style: AppTypography.headingSerif.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                helper,
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: 20),
              DrapeGradientButton(
                label: missingLabel,
                icon: canGenerate
                    ? Icons.auto_awesome_rounded
                    : Icons.add_a_photo_outlined,
                loading: canGenerate && _generating,
                onPressed: _generating
                    ? null
                    : canGenerate
                        ? () => _generate(occasion)
                        : () => context.pushNamed('camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherLine extends ConsumerWidget {
  const _WeatherLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return weatherAsync.when(
      loading: () => Shimmer.fromColors(
        baseColor: isDark ? AppColorsDark.border : AppColors.border,
        highlightColor: isDark ? AppColorsDark.card : AppColors.bgWarm,
        child: Container(
          width: 160,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      error: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 14, color: AppColors.ink3),
          const SizedBox(width: 4),
          Text('weather unavailable', style: AppTypography.caption),
        ],
      ),
      data: (weather) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.thermostat_rounded,
              size: 14, color: AppColors.orange),
          const SizedBox(width: 4),
          Text(
            weather.display,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
