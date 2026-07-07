import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/environment.dart';
import '../models/item_model.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const ItemCard({required this.item, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: item.ethnicFlag ? AppGradients.ethnic : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: item.ethnicFlag ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.card : AppColors.card,
            borderRadius: BorderRadius.circular(item.ethnicFlag ? 16 : 18),
            border: item.ethnicFlag
                ? null
                : Border.all(
                    color: isDark ? AppColorsDark.border : AppColors.border,
                  ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: Environment.resolveUrl(
                          item.thumbnailUrl ?? item.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? AppColorsDark.gray100 : AppColors.gray100,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? AppColorsDark.gray100 : AppColors.gray100,
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted(context)),
                      ),
                    ),
                    if (item.ethnicFlag)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppGradients.ethnic,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('✨',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subCategory.replaceAll('_', ' '),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.primaryColor,
                      style: AppTypography.caption.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
