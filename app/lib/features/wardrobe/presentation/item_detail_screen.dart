import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../providers/wardrobe_provider.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const ItemDetailScreen({required this.itemId, super.key});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  Map<String, dynamic>? _item;
  List<Map<String, dynamic>> _pairings = [];
  bool _loading = true;
  bool _loadingPairings = false;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getItem(widget.itemId);
      setState(() {
        _item = data;
        _loading = false;
      });
      _loadPairings();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPairings() async {
    setState(() => _loadingPairings = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getPairings(widget.itemId, limit: 5);
      setState(() {
        _pairings =
            List<Map<String, dynamic>>.from(data['pairings'] ?? const []);
      });
    } catch (_) {
      // silent — pairings are non-critical
    } finally {
      if (mounted) setState(() => _loadingPairings = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete item?',
            style: GoogleFonts.instrumentSerif(fontSize: 22)),
        content: Text('This item will be removed from your wardrobe.',
            style: AppTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.ink3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(wardrobeProvider.notifier).deleteItem(widget.itemId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }
    if (_item == null) {
      return Scaffold(
        body: Center(child: Text('Item not found',
            style: AppTypography.body)),
      );
    }

    final name = (_item!['sub_category'] ?? '').toString().replaceAll('_', ' ');
    final category = _item!['category'] ?? '';
    final subCategory = _item!['sub_category'] ?? '';
    final color = _item!['primary_color'] ?? '';
    final pattern = _item!['pattern'] ?? '';
    final fabric = _item!['fabric'] ?? '';
    final formality = _item!['formality'] ?? 3;
    final season = _item!['season'] ?? 'all';
    final wearCount = _item!['wear_count'] ?? 0;
    final imageUrl = _item!['image_url'] ?? '';

    return Scaffold(
      body: Column(
        children: [
          // Hero image — 52% of screen
          Expanded(
            flex: 52,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: AppColors.bgWarm,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: Environment.resolveUrl(imageUrl),
                          fit: BoxFit.contain,
                          placeholder: (_, __) =>
                              Container(color: AppColors.bgWarm),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: AppColors.ink3, size: 36),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20,
                          color: AppColors.ink),
                    ),
                  ),
                ),
                // Share button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 14,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_outlined, size: 18,
                          color: AppColors.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Detail content — remaining 48%
          Expanded(
            flex: 48,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category breadcrumb
                  Text(
                    '${category.toUpperCase()} · ${subCategory.toUpperCase()}'
                        .replaceAll('_', ' '),
                    style: AppTypography.mono.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: AppColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Item name
                  Text(
                    _capitalize(name),
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 30,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Tag stickers
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (fabric.isNotEmpty) _Sticker(fabric),
                      if (pattern.isNotEmpty) _Sticker(pattern),
                      _Sticker('f · $formality/5'),
                      if (season.toString().isNotEmpty)
                        _Sticker(_capitalize(season.toString())),
                      if (color.isNotEmpty) _Sticker(_capitalize(color)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Stat cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('WORN',
                                  style: AppTypography.mono.copyWith(
                                      fontSize: 10,
                                      letterSpacing: 0.6,
                                      color: AppColors.ink2)),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(children: [
                                  TextSpan(
                                    text: '$wearCount',
                                    style: GoogleFonts.instrumentSerif(
                                        fontSize: 26, color: AppColors.ink),
                                  ),
                                  TextSpan(
                                    text: ' times',
                                    style: GoogleFonts.instrumentSerif(
                                        fontSize: 12, color: AppColors.ink3),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('COST / WEAR',
                                  style: AppTypography.mono.copyWith(
                                      fontSize: 10,
                                      letterSpacing: 0.6,
                                      color: AppColors.ink2)),
                              const SizedBox(height: 4),
                              Text('--',
                                  style: GoogleFonts.instrumentSerif(
                                      fontSize: 26,
                                      color: AppColors.orange)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Pairs well with
                  if (_loadingPairings || _pairings.isNotEmpty) ...[
                    Text('PAIRS WELL WITH',
                        style: AppTypography.mono.copyWith(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            color: AppColors.ink2,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 130,
                      child: _loadingPairings && _pairings.isEmpty
                          ? const Center(
                              child: SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.orange),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _pairings.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, i) {
                                final p = _pairings[i];
                                return _PairingCard(
                                  imageUrl: p['image_url'] ?? '',
                                  name: (p['sub_category'] ?? p['category']
                                          ?? '')
                                      .toString()
                                      .replaceAll('_', ' '),
                                  score: (p['match_score'] as num?)?.round() ?? 0,
                                  reason: p['reason'] ?? '',
                                  onTap: () => context.pushNamed(
                                    'item_detail',
                                    pathParameters: {'id': p['id']},
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  // Meta info
                  Text('Added recently · in 0 outfits',
                      style: AppTypography.caption),
                  const SizedBox(height: 18),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextButton.icon(
                            onPressed: _delete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _PairingCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final int score;
  final String reason;
  final VoidCallback onTap;

  const _PairingCard({
    required this.imageUrl,
    required this.name,
    required this.score,
    required this.reason,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 110, height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.bgWarm,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: Environment.resolveUrl(imageUrl),
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.bgWarm),
                        )
                      : const SizedBox.shrink(),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$score',
                        style: AppTypography.mono.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.ink),
            ),
            Text(
              reason,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  final String text;
  const _Sticker(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: AppTypography.mono.copyWith(fontSize: 11,
              color: AppColors.ink2)),
    );
  }
}
