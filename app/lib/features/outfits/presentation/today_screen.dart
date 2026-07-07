import 'package:flutter/material.dart';
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
    ('festive', 'Festive ✨'),
    ('date', 'Date'),
  ];

  Future<void> _generate(String occasion) async {
    setState(() => _generating = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.generateOutfits(occasion.replaceAll(' ✨', ''));
      ref.invalidate(todayOutfitsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI had a moment — try again: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfitsAsync = ref.watch(todayOutfitsProvider);
    final occasion = ref.watch(selectedOccasionProvider);

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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _WeatherLine(),
              ),
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
                      onTap: () =>
                          ref.read(selectedOccasionProvider.notifier).state = key,
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
                          const Text('🌧️', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 12),
                          Text('fits didn\'t load', style: AppTypography.title),
                          const SizedBox(height: 12),
                          DrapeGradientButton(
                            label: 'Retry',
                            onPressed: () => ref.invalidate(todayOutfitsProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (outfits) => outfits.isEmpty
                      ? _buildEmpty(occasion)
                      : RefreshIndicator(
                          color: AppColors.orange,
                          onRefresh: () async => _generate(occasion),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            itemCount: outfits.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (_, i) => TweenAnimationBuilder<double>(
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

  Widget _buildEmpty(String occasion) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: DrapeGlassCard(
          gradientBorder: true,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                'no $occasion fits yet',
                style: AppTypography.headingSerif.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'hit generate — AI picks from your closet in seconds',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: 20),
              DrapeGradientButton(
                label: 'Generate fits',
                icon: Icons.auto_awesome_rounded,
                loading: _generating,
                onPressed: _generating ? null : () => _generate(occasion),
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
      error: (_, __) => Text(
        '🌤 weather unavailable',
        style: AppTypography.caption,
      ),
      data: (weather) => Text(
        '🌡 ${weather.display}',
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.orange,
        ),
      ),
    );
  }
}
