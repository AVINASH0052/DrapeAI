import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../models/outfit_model.dart';
import 'outfit_chat_sheet.dart';

class OutfitCard extends ConsumerStatefulWidget {
  final Outfit outfit;
  const OutfitCard({required this.outfit, super.key});

  @override
  ConsumerState<OutfitCard> createState() => _OutfitCardState();
}

class _OutfitCardState extends ConsumerState<OutfitCard> {
  bool _liked = false;
  bool _disliked = false;
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final outfit = widget.outfit;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // AI accent border
          Container(height: 2, color: AppColors.orange),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        outfit.occasion.toUpperCase(),
                        style: AppTypography.mono.copyWith(
                            fontSize: 10.5,
                            letterSpacing: 0.4),
                      ),
                    ),
                    if (outfit.weather != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${outfit.weather!['temp']}° ${outfit.weather!['condition']}',
                        style: AppTypography.caption,
                      ),
                    ],
                    const Spacer(),
                    if (outfit.ruleScore > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${outfit.ruleScore.round()}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Item circles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: outfit.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: Environment.resolveUrl(item.imageUrl),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                color: AppColors.gray100),
                            errorWidget: (_, __, ___) => Container(
                                color: AppColors.gray100,
                                child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 18,
                                    color: AppColors.gray400)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Reason text
                if (outfit.reason != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    '"${outfit.reason!}"',
                    style: AppTypography.body.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionBtn(
                      icon: Icons.thumb_up_outlined,
                      activeIcon: Icons.thumb_up,
                      label: 'Love',
                      active: _liked,
                      activeColor: AppColors.lime,
                      onTap: () {
                        setState(() { _liked = !_liked; _disliked = false; });
                        ref.read(apiClientProvider)
                            .submitFeedback(outfit.id, 'like');
                      },
                    ),
                    _ActionBtn(
                      icon: Icons.thumb_down_outlined,
                      activeIcon: Icons.thumb_down,
                      label: 'Pass',
                      active: _disliked,
                      activeColor: AppColors.red,
                      onTap: () {
                        setState(() { _disliked = !_disliked; _liked = false; });
                        ref.read(apiClientProvider)
                            .submitFeedback(outfit.id, 'dislike');
                      },
                    ),
                    _ActionBtn(
                      icon: Icons.bookmark_outline,
                      activeIcon: Icons.bookmark,
                      label: 'Save',
                      active: _saved,
                      activeColor: AppColors.orange,
                      onTap: () {
                        setState(() => _saved = !_saved);
                        ref.read(apiClientProvider)
                            .submitFeedback(outfit.id, 'save');
                      },
                    ),
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline,
                      activeIcon: Icons.chat_bubble,
                      label: 'Tweak',
                      active: false,
                      activeColor: AppColors.lavender,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => OutfitChatSheet(outfit: outfit),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 20,
              color: active ? activeColor : AppColors.ink3,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? activeColor : AppColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
