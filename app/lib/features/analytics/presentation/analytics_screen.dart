import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overviewAsync = ref.watch(analyticsOverviewProvider);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final wearAsync = ref.watch(wearHistoryProvider(30));

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 28),
            children: [
              const DrapeScreenHeader(
                title: 'Analytics',
                subtitle: 'how you wear your closet',
                gradientTitle: true,
              ),
            const SizedBox(height: 8),

            // Hero utilization card
            overviewAsync.when(
              loading: () => _buildHeroShimmer(isDark),
              error: (_, __) => _buildHeroError(isDark),
              data: (overview) => _buildHeroCard(overview, isDark),
            ),
            const SizedBox(height: 16),

            // Stats row
            overviewAsync.when(
              loading: () => _buildStatsRowShimmer(isDark),
              error: (_, __) => const SizedBox.shrink(),
              data: (overview) => _buildStatsRow(overview, isDark),
            ),
            const SizedBox(height: 8),

            // Style diversity
            overviewAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (overview) => _buildDiversityCard(overview, isDark),
            ),

            // Wear history
            const DrapeSectionLabel('Wear history'),
            wearAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (entries) => _buildWearHistory(entries, isDark),
            ),

            // Category breakdown
            const DrapeSectionLabel('Category breakdown'),
            breakdownAsync.when(
              loading: () => _buildBreakdownShimmer(isDark),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Could not load breakdown',
                    style: AppTypography.body),
              ),
              data: (categories) => overviewAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => _buildCategoryBreakdown(categories, isDark),
                data: (overview) => _buildCategoryBreakdown(
                  categories,
                  isDark,
                  mostWorn: overview['most_worn_category'] as String?,
                  leastWorn: overview['least_worn_category'] as String?,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildWearHistory(List<Map<String, dynamic>> entries, bool isDark) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DrapeGlassCard(
          child: Text('No wears logged yet — assign outfits on Calendar',
              style: AppTypography.body),
        ),
      );
    }
    final maxWears = entries
        .map((e) => (e['outfits_worn'] as num?)?.toInt() ?? 0)
        .fold<int>(1, (a, b) => b > a ? b : a);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: DrapeGlassCard(
        child: SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: entries.take(14).map((e) {
              final wears = (e['outfits_worn'] as num?)?.toInt() ?? 0;
              final h = (wears / maxWears * 72).clamp(4.0, 72.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          gradient: AppGradients.cta,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── Hero Utilization Card ─────────────────────────────────────────

  Widget _buildHeroCard(Map<String, dynamic> overview, bool isDark) {
    final utilization = (overview['utilization_pct'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColorsDark.card, AppColorsDark.bgWarm]
                : [AppColors.card, AppColors.bgWarm],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _RadialGaugePainter(
                  progress: utilization / 100,
                  trackColor: isDark ? AppColorsDark.border : AppColors.border,
                  progressColor:
                      isDark ? AppColorsDark.orange : AppColors.orange,
                  strokeWidth: 10,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${utilization.round()}%',
                          style: GoogleFonts.instrumentSerif(
                              fontSize: 32,
                              color:
                                  isDark ? AppColorsDark.ink : AppColors.ink,
                              height: 1)),
                      const SizedBox(height: 2),
                      Text('utilised',
                          style: AppTypography.caption.copyWith(
                              fontSize: 11,
                              color: isDark
                                  ? AppColorsDark.ink3
                                  : AppColors.ink3)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Wardrobe Utilization',
                style: AppTypography.title.copyWith(
                    color: isDark ? AppColorsDark.ink : AppColors.ink)),
            const SizedBox(height: 4),
            Text('Percentage of items worn in the last 30 days',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                    color: isDark ? AppColorsDark.ink3 : AppColors.ink3)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroShimmer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: isDark ? AppColorsDark.border : AppColors.border,
        highlightColor: isDark ? AppColorsDark.bgWarm : AppColors.bgWarm,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.card : AppColors.card,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroError(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.card : AppColors.card,
          border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text('Unable to load analytics',
              style: AppTypography.body.copyWith(
                  color: isDark ? AppColorsDark.ink3 : AppColors.ink3)),
        ),
      ),
    );
  }

  // ─── Stats Row ─────────────────────────────────────────────────────

  Widget _buildStatsRow(Map<String, dynamic> overview, bool isDark) {
    final items = overview['total_items'] ?? 0;
    final outfits = overview['outfits_saved'] ?? 0;
    final avgWears = overview['avg_wear_count'] ?? overview['avg_wears'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatCard(
            value: '$items',
            label: 'Total items',
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: '$outfits',
            label: 'Outfits saved',
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: '$avgWears',
            label: 'Avg wears',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRowShimmer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(
          3,
          (_) => Expanded(
            child: Shimmer.fromColors(
              baseColor: isDark ? AppColorsDark.border : AppColors.border,
              highlightColor:
                  isDark ? AppColorsDark.bgWarm : AppColors.bgWarm,
              child: Container(
                height: 72,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.card : AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Style Diversity ──────────────────────────────────────────────

  Widget _buildDiversityCard(Map<String, dynamic> overview, bool isDark) {
    final diversity =
        (overview['style_diversity'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.card : AppColors.card,
          border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CustomPaint(
                painter: _RadialGaugePainter(
                  progress: diversity / 100,
                  trackColor: isDark ? AppColorsDark.border : AppColors.border,
                  progressColor: AppColors.lavender,
                  strokeWidth: 5,
                ),
                child: Center(
                  child: Text('${diversity.round()}',
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 16,
                          color:
                              isDark ? AppColorsDark.ink : AppColors.ink)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Style Diversity',
                      style: AppTypography.label.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColorsDark.ink : AppColors.ink)),
                  Text('How varied your outfit choices are',
                      style: AppTypography.caption.copyWith(
                          color:
                              isDark ? AppColorsDark.ink3 : AppColors.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category Breakdown ───────────────────────────────────────────

  Widget _buildCategoryBreakdown(
    List<Map<String, dynamic>> categories,
    bool isDark, {
    String? mostWorn,
    String? leastWorn,
  }) {

    // Find max item count for bar scaling
    int maxItems = 1;
    for (final c in categories) {
      final count = (c['item_count'] as num?)?.toInt() ?? 0;
      if (count > maxItems) maxItems = count;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Highlight cards
          if (mostWorn != null || leastWorn != null) ...[
            Row(
              children: [
                if (mostWorn != null)
                  Expanded(
                    child: _HighlightCard(
                      label: 'Most worn',
                      category: _capitalize(mostWorn),
                      icon: Icons.trending_up,
                      color: isDark ? AppColorsDark.green500 : AppColors.green500,
                      bgColor: isDark ? AppColorsDark.green50 : AppColors.green50,
                      isDark: isDark,
                    ),
                  ),
                if (mostWorn != null && leastWorn != null)
                  const SizedBox(width: 10),
                if (leastWorn != null)
                  Expanded(
                    child: _HighlightCard(
                      label: 'Least worn',
                      category: _capitalize(leastWorn),
                      icon: Icons.trending_down,
                      color: isDark ? AppColorsDark.amber500 : AppColors.amber500,
                      bgColor: isDark ? AppColorsDark.amber50 : AppColors.amber50,
                      isDark: isDark,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Category rows
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColorsDark.card : AppColors.card,
              border: Border.all(
                  color: isDark ? AppColorsDark.border : AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: List.generate(categories.length, (i) {
                final cat = categories[i];
                final name = _capitalize(cat['name']?.toString() ?? '');
                final itemCount = (cat['item_count'] as num?)?.toInt() ?? 0;
                final wearCount = (cat['wear_count'] as num?)?.toInt() ?? 0;
                final cpwPaise = (cat['cost_per_wear'] as num?)?.toInt();
                final cpwDisplay = cpwPaise != null
                    ? '₹${(cpwPaise / 100).round()}'
                    : '—';
                final fraction = maxItems > 0 ? itemCount / maxItems : 0.0;

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: i < categories.length - 1
                        ? Border(
                            bottom: BorderSide(
                                color: isDark
                                    ? AppColorsDark.border
                                    : AppColors.border))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: AppTypography.label.copyWith(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColorsDark.ink
                                        : AppColors.ink)),
                          ),
                          Text('$itemCount items',
                              style: AppTypography.caption.copyWith(
                                  color: isDark
                                      ? AppColorsDark.ink3
                                      : AppColors.ink3)),
                          const SizedBox(width: 12),
                          Text('$wearCount wears',
                              style: AppTypography.caption.copyWith(
                                  color: isDark
                                      ? AppColorsDark.ink3
                                      : AppColors.ink3)),
                          const SizedBox(width: 12),
                          Text(cpwDisplay,
                              style: AppTypography.mono.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColorsDark.orange
                                      : AppColors.orange)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: fraction,
                            backgroundColor:
                                isDark ? AppColorsDark.border : AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isDark
                                    ? AppColorsDark.orange
                                    : AppColors.orange),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownShimmer(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: isDark ? AppColorsDark.border : AppColors.border,
        highlightColor: isDark ? AppColorsDark.bgWarm : AppColors.bgWarm,
        child: Column(
          children: List.generate(
            4,
            (_) => Container(
              height: 64,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColorsDark.card : AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ─── Private Widgets ─────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionHead(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(text.toUpperCase(),
          style: AppTypography.mono.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColorsDark.ink2 : AppColors.ink2,
              letterSpacing: 0.8)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _StatCard({
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.card : AppColors.card,
          border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.instrumentSerif(
                    fontSize: 24,
                    color: isDark ? AppColorsDark.ink : AppColors.ink,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label,
                style: AppTypography.caption.copyWith(
                    color: isDark ? AppColorsDark.ink3 : AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String label;
  final String category;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isDark;

  const _HighlightCard({
    required this.label,
    required this.category,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.caption.copyWith(
                        color: color, fontSize: 10)),
                Text(category,
                    style: AppTypography.label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColorsDark.ink : AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RadialGaugePainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter old) =>
      old.progress != progress;
}
