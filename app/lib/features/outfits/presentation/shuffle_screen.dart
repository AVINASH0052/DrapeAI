import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../models/outfit_model.dart';

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
          SnackBar(content: Text('Shuffle failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onDragEnd() async {
    if (_dragOffset.dx > 80) {
      // Save
      if (_currentOutfit != null) {
        await ref.read(apiClientProvider)
            .submitFeedback(_currentOutfit!.id, 'save');
      }
      _shuffle();
    } else if (_dragOffset.dx < -80) {
      // Skip
      if (_currentOutfit != null) {
        await ref.read(apiClientProvider)
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back, size: 20,
                          color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shuffle',
                          style: GoogleFonts.instrumentSerif(
                            fontSize: 22, fontWeight: FontWeight.w400,
                            color: AppColors.ink)),
                      Text('Swipe right to save, left to skip',
                          style: AppTypography.caption),
                    ],
                  ),
                ],
              ),
            ),
            // Swipe area
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.orange))
                  : _currentOutfit == null
                      ? _buildEmpty()
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          child: GestureDetector(
                            onPanStart: (_) =>
                                setState(() => _dragging = true),
                            onPanUpdate: (d) =>
                                setState(() => _dragOffset += d.delta),
                            onPanEnd: (_) => _onDragEnd(),
                            child: AnimatedContainer(
                              duration: _dragging
                                  ? Duration.zero
                                  : const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                              transform: Matrix4.identity()
                                ..translate(_dragOffset.dx,
                                    _dragOffset.dy * 0.4)
                                ..rotateZ(_dragOffset.dx * 0.001),
                              child: Stack(
                                children: [
                                  _buildSwipeCard(),
                                  if (_dragOffset.dx > 30)
                                    Positioned(
                                      top: 24, left: 24,
                                      child: _SwipeLabel(
                                          text: 'SAVE',
                                          color: AppColors.lime),
                                    ),
                                  if (_dragOffset.dx < -30)
                                    Positioned(
                                      top: 24, right: 24,
                                      child: _SwipeLabel(
                                          text: 'SKIP',
                                          color: AppColors.red),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
            ),
            // Bottom action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleAction(
                    icon: Icons.close,
                    color: AppColors.red,
                    size: 60,
                    onTap: () {
                      if (_currentOutfit != null) {
                        ref.read(apiClientProvider)
                            .submitFeedback(_currentOutfit!.id, 'skip');
                        _shuffle();
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  _CircleAction(
                    icon: Icons.favorite,
                    color: Colors.white,
                    bgColor: AppColors.orange,
                    size: 72,
                    onTap: () {
                      if (_currentOutfit != null) {
                        ref.read(apiClientProvider)
                            .submitFeedback(_currentOutfit!.id, 'save');
                        _shuffle();
                      }
                    },
                  ),
                  const SizedBox(width: 24),
                  _CircleAction(
                    icon: Icons.shuffle,
                    size: 60,
                    onTap: _shuffle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shuffle, size: 48, color: AppColors.ink3),
          const SizedBox(height: 16),
          Text('Tap shuffle to get started', style: AppTypography.body),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: _shuffle,
              child: const Text('Shuffle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeCard() {
    final outfit = _currentOutfit!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header block
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.bgWarm,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      outfit.occasion.toUpperCase(),
                      style: AppTypography.mono.copyWith(
                          color: Colors.white, fontSize: 10.5),
                    ),
                  ),
                ),
                if (outfit.ruleScore > 0)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${outfit.ruleScore.round()}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16, fontWeight: FontWeight.w600,
                          color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Items + reason
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: outfit.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            width: 100, height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: Environment.resolveUrl(item.imageUrl),
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.gray100),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.gray100,
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.gray400),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (outfit.reason != null) ...[
                    Text(
                      '"${outfit.reason!}"',
                      style: GoogleFonts.instrumentSerif(
                        fontSize: 18,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SwipeLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: text == 'SAVE' ? -0.2 : 0.2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: color, letterSpacing: 0.6)),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? bgColor;
  final double size;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    this.color,
    this.bgColor,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: bgColor ?? AppColors.card,
          shape: BoxShape.circle,
          border: bgColor == null
              ? Border.all(color: AppColors.border)
              : null,
          boxShadow: [
            BoxShadow(
              color: (bgColor ?? Colors.black).withValues(alpha: bgColor != null ? 0.35 : 0.06),
              blurRadius: bgColor != null ? 24 : 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.38,
            color: color ?? AppColors.ink),
      ),
    );
  }
}
