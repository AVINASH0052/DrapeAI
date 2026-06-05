import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Compact cost-per-wear stat card for item detail screens.
///
/// Shows purchase_price ÷ wear_count = cost per wear.
/// Color-coded: green (<₹100), amber (₹100–500), red (>₹500).
/// [purchasePricePaise] is stored in paise — divide by 100 for display.
class CostPerWearCard extends StatelessWidget {
  final int? purchasePricePaise;
  final int wearCount;
  final VoidCallback? onAddPrice;

  const CostPerWearCard({
    required this.purchasePricePaise,
    required this.wearCount,
    this.onAddPrice,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No purchase price — show prompt
    if (purchasePricePaise == null) {
      return GestureDetector(
        onTap: onAddPrice,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.card : AppColors.card,
            border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.orangeSoft : AppColors.orangeSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add,
                    size: 18,
                    color: isDark ? AppColorsDark.orange : AppColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add purchase price',
                        style: AppTypography.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColorsDark.ink : AppColors.ink)),
                    Text('Track your cost per wear',
                        style: AppTypography.caption.copyWith(
                            color:
                                isDark ? AppColorsDark.ink3 : AppColors.ink3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 16,
                  color: isDark ? AppColorsDark.ink3 : AppColors.ink3),
            ],
          ),
        ),
      );
    }

    final priceRupees = purchasePricePaise! / 100;
    final cpw = wearCount > 0 ? priceRupees / wearCount : priceRupees;
    final cpwRounded = cpw.round();

    // Determine color band
    final Color accentColor;
    final Color accentBg;
    final String verdict;
    if (cpw < 100) {
      accentColor = isDark ? AppColorsDark.green500 : AppColors.green500;
      accentBg = isDark ? AppColorsDark.green50 : AppColors.green50;
      verdict = 'Great value';
    } else if (cpw <= 500) {
      accentColor = isDark ? AppColorsDark.amber500 : AppColors.amber500;
      accentBg = isDark ? AppColorsDark.amber50 : AppColors.amber50;
      verdict = 'Good';
    } else {
      accentColor = isDark ? AppColorsDark.red : AppColors.red;
      accentBg = isDark ? AppColorsDark.red50 : AppColors.red50;
      verdict = 'Wear more';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.card : AppColors.card,
        border: Border.all(color: isDark ? AppColorsDark.border : AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('COST PER WEAR',
                  style: AppTypography.mono.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: isDark ? AppColorsDark.ink2 : AppColors.ink2)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(verdict,
                    style: AppTypography.mono.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: accentColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$cpwRounded',
                  style: GoogleFonts.instrumentSerif(
                      fontSize: 28, color: accentColor, height: 1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('/wear',
                    style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color:
                            isDark ? AppColorsDark.ink3 : AppColors.ink3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Breakdown line
          Text(
            '₹${priceRupees.round()} ÷ ${wearCount > 0 ? '$wearCount wears' : '0 wears'}',
            style: AppTypography.caption.copyWith(
                color: isDark ? AppColorsDark.ink3 : AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
