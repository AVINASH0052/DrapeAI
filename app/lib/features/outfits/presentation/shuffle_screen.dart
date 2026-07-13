import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../../../core/widgets/drape_ui.dart';
import '../models/outfit_model.dart';
import '../widgets/outfit_visualize_sheet.dart';

class ShuffleScreen extends ConsumerStatefulWidget {
  const ShuffleScreen({super.key});

  @override
  ConsumerState<ShuffleScreen> createState() => _ShuffleScreenState();
}

class _ShuffleScreenState extends ConsumerState<ShuffleScreen> {
  Outfit? _currentOutfit;
  bool _loading = false;
  String _occasion = 'casual';
  Offset _dragOffset = Offset.zero;
  bool _dragging = false;

  static const _occasions = [
    ('casual', 'Casual'),
    ('work', 'Work'),
    ('party', 'Party'),
    ('festive', 'Festive'),
    ('date', 'Date'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _shuffle());
  }

  Future<void> _shuffle() async {
    setState(() {
      _loading = true;
      _currentOutfit = null;
      _dragOffset = Offset.zero;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.shuffleOutfit(_occasion);
      if (data['outfit'] != null) {
        setState(() => _currentOutfit = Outfit.fromJson(data['outfit']));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shuffle failed: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDragEnd() async {
    if (_dragOffset.dx > 80) {
      if (_currentOutfit != null) {
        await ref
            .read(apiClientProvider)
            .submitFeedback(_currentOutfit!.id, 'save');
      }
      _shuffle();
    } else if (_dragOffset.dx < -80) {
      if (_currentOutfit != null) {
        await ref
            .read(apiClientProvider)
            .submitFeedback(_currentOutfit!.id, 'skip');
      }
      _shuffle();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    DrapeIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (_) => AppGradients.hero
                                .createShader(const Rect.fromLTWH(0, 0, 200, 36)),
                            child: Text(
                              'Shuffle',
                              style: GoogleFonts.syne(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            'swipe right = save · left = skip',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: _occasions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (key, label) = _occasions[i];
                    return DrapeChip(
                      label: label,
                      active: _occasion == key,
                      onTap: () {
                        setState(() => _occasion = key);
                        _shuffle();
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.orange),
                      )
                    : _currentOutfit == null
                        ? _buildEmpty()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: GestureDetector(
                              onPanStart: (_) => setState(() => _dragging = true),
                              onPanUpdate: (d) =>
                                  setState(() => _dragOffset += d.delta),
                              onPanEnd: (_) => _onDragEnd(),
                              child: AnimatedContainer(
                                duration: _dragging
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                curve: Curves.easeOutBack,
                                transform: Matrix4.identity()
                                  ..translate(_dragOffset.dx, _dragOffset.dy * 0.35)
                                  ..rotateZ(_dragOffset.dx * 0.0012),
                                child: Stack(
                                  children: [
                                    _buildSwipeCard(),
                                    if (_dragOffset.dx > 30)
                                      const Positioned(
                                        top: 28,
                                        left: 28,
                                        child: _SwipeStamp(
                                          label: 'SAVE',
                                          emoji: '💚',
                                          color: AppColors.lime,
                                        ),
                                      ),
                                    if (_dragOffset.dx < -30)
                                      const Positioned(
                                        top: 28,
                                        right: 28,
                                        child: _SwipeStamp(
                                          label: 'NAH',
                                          emoji: '👋',
                                          color: AppColors.red,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleAction(
                      icon: Icons.close_rounded,
                      gradient: const LinearGradient(
                        colors: [AppColors.red, Color(0xFFFF4D6D)],
                      ),
                      size: 58,
                      onTap: () {
                        if (_currentOutfit != null) {
                          ref
                              .read(apiClientProvider)
                              .submitFeedback(_currentOutfit!.id, 'skip');
                          _shuffle();
                        }
                      },
                    ),
                    const SizedBox(width: 28),
                    _CircleAction(
                      icon: Icons.favorite_rounded,
                      gradient: AppGradients.cta,
                      size: 72,
                      onTap: () {
                        if (_currentOutfit != null) {
                          ref
                              .read(apiClientProvider)
                              .submitFeedback(_currentOutfit!.id, 'save');
                          _shuffle();
                        }
                      },
                    ),
                    const SizedBox(width: 28),
                    _CircleAction(
                      icon: Icons.shuffle_rounded,
                      size: 58,
                      onTap: _shuffle,
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

  Widget _buildEmpty() {
    return Center(
      child: DrapeGlassCard(
        gradientBorder: true,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎲', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'no fits to shuffle',
              style: AppTypography.headingSerif.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'add more pieces to your closet first',
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            DrapeGradientButton(
              label: 'Try again',
              onPressed: _shuffle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeCard() {
    final outfit = _currentOutfit!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: AppGradients.hero,
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.card : AppColors.card,
          borderRadius: BorderRadius.circular(26),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: AppGradients.heroSoft,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppGradients.cta,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        outfit.occasion.toUpperCase(),
                        style: AppTypography.mono.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (outfit.ruleScore > 0)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.goldSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '${outfit.ruleScore.round()}',
                              style: GoogleFonts.spaceMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  children: [
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: outfit.items.map((item) {
                          return Container(
                            width: 96,
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: AppGradients.hero,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl:
                                    Environment.resolveUrl(item.imageUrl),
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.gray100),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.gray100,
                                  child: const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (outfit.reason != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '"${outfit.reason!}"',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textMuted(context),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    DrapeGradientButton(
                      label: 'See me in this',
                      onPressed: () =>
                          showOutfitVisualizeSheet(context, outfit),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeStamp extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;

  const _SwipeStamp({
    required this.label,
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: label == 'SAVE' ? -0.25 : 0.25,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Gradient? gradient;
  final double size;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    this.gradient,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null
              ? (isDark ? AppColorsDark.card : AppColors.card)
              : null,
          shape: BoxShape.circle,
          border: gradient == null
              ? Border.all(
                  color: isDark ? AppColorsDark.border : AppColors.border)
              : null,
          boxShadow: [
            BoxShadow(
              color: (gradient != null ? AppColors.orange : Colors.black)
                  .withValues(alpha: gradient != null ? 0.35 : 0.08),
              blurRadius: gradient != null ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: gradient != null ? Colors.white : AppColors.textPrimary(context),
        ),
      ),
    );
  }
}
