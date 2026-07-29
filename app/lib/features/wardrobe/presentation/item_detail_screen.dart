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
import '../widgets/cost_per_wear_card.dart';

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
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.ink3),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(wardrobeProvider.notifier).deleteItem(widget.itemId);
      if (mounted) context.pop();
    }
  }

  Future<void> _edit() async {
    final item = _item;
    if (item == null) return;

    final nameController = TextEditingController(
      text: (item['display_name'] ?? '').toString(),
    );
    final remarksController = TextEditingController(
      text: (item['notes'] ?? '').toString(),
    );
    final categoryController = TextEditingController(
      text: (item['category'] ?? '').toString(),
    );
    final colorController = TextEditingController(
      text: (item['primary_color'] ?? '').toString(),
    );

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit piece',
                  style: GoogleFonts.syne(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your changes override the AI labels.',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'White everyday tee',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'top',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: colorController,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          hintText: 'white',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  maxLength: 500,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Fit, styling notes, where you bought it...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save changes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (save != true || !mounted) {
      nameController.dispose();
      remarksController.dispose();
      categoryController.dispose();
      colorController.dispose();
      return;
    }

    try {
      await ref.read(apiClientProvider).updateItem(widget.itemId, {
        'display_name': nameController.text.trim(),
        'notes': remarksController.text.trim(),
        'category': categoryController.text.trim().toLowerCase(),
        'primary_color': colorController.text.trim().toLowerCase(),
      });
      ref.invalidate(wardrobeProvider);
      await _loadItem();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Piece updated')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save changes. Please try again.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      nameController.dispose();
      remarksController.dispose();
      categoryController.dispose();
      colorController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }
    if (_item == null) {
      return Scaffold(
        body: Center(child: Text('Item not found', style: AppTypography.body)),
      );
    }

    final name = (_item!['display_name'] ?? _item!['sub_category'] ?? '')
        .toString()
        .replaceAll('_', ' ');
    final category = _item!['category'] ?? '';
    final subCategory = _item!['sub_category'] ?? '';
    final color = _item!['primary_color'] ?? '';
    final pattern = _item!['pattern'] ?? '';
    final fabric = _item!['fabric'] ?? '';
    final formality = _item!['formality'] ?? 3;
    final seasons = _item!['season_tags'];
    final season =
        seasons is List && seasons.isNotEmpty ? seasons.first : 'all';
    final wearCount = _item!['wear_count'] ?? 0;
    final imageUrl = _item!['image_url'] ?? '';
    final remarks = (_item!['notes'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.58,
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
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.ink3,
                                size: 36,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 14,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 14,
                    right: 16,
                    child: GestureDetector(
                      onTap: _edit,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 132),
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
                        child: CostPerWearCard(
                          purchasePricePaise:
                              (_item!['purchase_price'] as num?)?.toInt(),
                          wearCount: wearCount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (remarks.isNotEmpty) ...[
                    Text(
                      'REMARKS',
                      style: AppTypography.mono.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: AppColors.ink2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(remarks, style: AppTypography.body),
                    const SizedBox(height: 18),
                  ],
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
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.orange),
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
                                  name:
                                      (p['sub_category'] ?? p['category'] ?? '')
                                          .toString()
                                          .replaceAll('_', ' '),
                                  score:
                                      (p['match_score'] as num?)?.round() ?? 0,
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
                            onPressed: _edit,
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
                  width: 110,
                  height: 90,
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
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
          style:
              AppTypography.mono.copyWith(fontSize: 11, color: AppColors.ink2)),
    );
  }
}
