import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../providers/today_provider.dart';
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
    ('festive', 'Festive'),
    ('date', 'Date Night'),
  ];

  Future<void> _generate(String occasion) async {
    setState(() => _generating = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.generateOutfits(occasion);
      ref.invalidate(todayOutfitsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Generation failed: $e'),
              backgroundColor: AppColors.red),
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
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today',
                            style: GoogleFonts.instrumentSerif(
                              fontSize: 26,
                              fontWeight: FontWeight.w400,
                              color: AppColors.ink,
                            )),
                        const SizedBox(height: 2),
                        Text('Mumbai · light breeze, 28°',
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.pushNamed('shuffle'),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.shuffle, size: 20, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            // Occasion chips
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                itemCount: _occasions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (key, label) = _occasions[i];
                  final isActive = occasion == key;
                  return GestureDetector(
                    onTap: () => ref.read(selectedOccasionProvider.notifier).state = key,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.ink : const Color(0xFFF1EFEB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(label,
                          style: AppTypography.chip.copyWith(
                              color: isActive ? Colors.white : AppColors.ink2)),
                    ),
                  );
                },
              ),
            ),
            // Outfits list
            Expanded(
              child: outfitsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.orange)),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load outfits', style: AppTypography.body),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(todayOutfitsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (outfits) => outfits.isEmpty
                    ? _buildEmpty(occasion)
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _generate(occasion);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                                    offset: Offset(0, 12 * (1 - value)),
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
    );
  }

  Widget _buildEmpty(String occasion) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Nothing yet for $occasion.',
                    style: AppTypography.body.copyWith(color: AppColors.ink3),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _generating ? null : () => _generate(occasion),
                      child: _generating
                          ? const SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Generate outfits'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
