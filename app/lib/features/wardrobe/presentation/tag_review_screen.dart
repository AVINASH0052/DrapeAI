import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../../../core/widgets/drape_ui.dart';
import '../providers/wardrobe_provider.dart';

class TagReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;
  const TagReviewScreen({required this.itemData, super.key});

  @override
  ConsumerState<TagReviewScreen> createState() => _TagReviewScreenState();
}

class _TagReviewScreenState extends ConsumerState<TagReviewScreen> {
  late Map<String, dynamic> _tags;
  late List<String> _seasons;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tags = Map<String, dynamic>.from(widget.itemData['tags'] ?? {});
    _seasons = List<String>.from(_tags['season'] ?? ['all']);
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      _tags['season'] = _seasons;
      await api.updateItem(widget.itemData['id'], _tags);
      // Force wardrobe to refetch so the new item is visible immediately.
      ref.invalidate(wardrobeProvider);
      if (mounted) context.go('/wardrobe');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidence = ((_tags['confidence'] ?? 0.92) * 100).round();

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              DrapeScreenHeader(
                title: 'AI tags',
                subtitle: 'tweak before saving',
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                ],
              ),
            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // Item preview + AI badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 200, height: 220,
                            decoration: BoxDecoration(
                              color: AppColors.bgWarm,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: Environment.resolveUrl(
                                    widget.itemData['image_url'] ?? ''),
                                fit: BoxFit.contain,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.bgWarm),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      color: AppColors.ink3, size: 36),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10, right: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.orange,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '✶ AI · $confidence%',
                                style: AppTypography.mono.copyWith(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Category
                  _TagSection(
                    label: 'Category',
                    child: _ChipSelector(
                      options: const [
                        'top', 'bottom', 'ethnic', 'footwear',
                        'accessory', 'outerwear',
                      ],
                      selected: _tags['category'] ?? '',
                      onChanged: (v) =>
                          setState(() => _tags['category'] = v),
                    ),
                  ),

                  // Sub-category
                  _TagSection(
                    label: 'Sub-category',
                    child: _ChipSelector(
                      options: const [
                        'kurta', 'shirt', 'polo', 't-shirt',
                        'hoodie', 'blazer', 'jeans', 'chinos',
                      ],
                      selected: _tags['sub_category'] ?? '',
                      onChanged: (v) =>
                          setState(() => _tags['sub_category'] = v),
                    ),
                  ),

                  // Color
                  _TagSection(
                    label: 'Color',
                    child: _ColorChipSelector(
                      options: const {
                        'navy': Color(0xFF1E3A5F),
                        'black': Color(0xFF1A1A1A),
                        'white': Color(0xFFF4F1E8),
                        'beige': Color(0xFFD6CFC2),
                        'olive': Color(0xFF6B7A4F),
                        'rust': Color(0xFFA6532A),
                      },
                      selected: _tags['primary_color'] ?? '',
                      onChanged: (v) =>
                          setState(() => _tags['primary_color'] = v),
                    ),
                  ),

                  // Pattern
                  _TagSection(
                    label: 'Pattern',
                    child: _ChipSelector(
                      options: const [
                        'solid', 'striped', 'floral',
                        'checked', 'printed',
                      ],
                      selected: _tags['pattern'] ?? '',
                      onChanged: (v) =>
                          setState(() => _tags['pattern'] = v),
                    ),
                  ),

                  // Fabric
                  _TagSection(
                    label: 'Fabric',
                    child: _ChipSelector(
                      options: const [
                        'cotton', 'silk', 'denim',
                        'linen', 'wool',
                      ],
                      selected: _tags['fabric'] ?? '',
                      onChanged: (v) =>
                          setState(() => _tags['fabric'] = v),
                    ),
                  ),

                  // Formality
                  _TagSection(
                    label: 'Formality',
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: List.generate(5, (i) {
                              final n = i + 1;
                              final selected =
                                  (_tags['formality'] ?? 3) == n;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      right: i < 4 ? 8 : 0),
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _tags['formality'] = n),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.ink
                                            : AppColors.card,
                                        border: selected
                                            ? null
                                            : Border.all(
                                                color: AppColors.border),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$n',
                                          style:
                                              GoogleFonts.jetBrainsMono(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: selected
                                                ? Colors.white
                                                : AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Casual', style: AppTypography.caption),
                              Text('Formal', style: AppTypography.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Season
                  _TagSection(
                    label: 'Season',
                    child: _ChipSelector(
                      options: const [
                        'summer', 'winter', 'monsoon', 'all',
                      ],
                      selected: _seasons.isNotEmpty ? _seasons.first : '',
                      multi: true,
                      multiSelected: _seasons,
                      onChanged: (v) {
                        setState(() {
                          if (_seasons.contains(v)) {
                            _seasons.remove(v);
                          } else {
                            _seasons.add(v);
                          }
                        });
                      },
                    ),
                  ),

                  // Save button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _confirm,
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('Save to wardrobe'),
                      ),
                    ),
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

class _TagSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _TagSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.mono.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.ink2,
              letterSpacing: 0.8,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ChipSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final bool multi;
  final List<String>? multiSelected;
  final ValueChanged<String> onChanged;

  const _ChipSelector({
    required this.options,
    required this.selected,
    this.multi = false,
    this.multiSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: options.map((opt) {
          final isSelected = multi
              ? (multiSelected ?? []).contains(opt)
              : opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.ink : AppColors.card,
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _capitalize(opt),
                  style: AppTypography.label.copyWith(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _ColorChipSelector extends StatelessWidget {
  final Map<String, Color> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _ColorChipSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: options.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.ink : AppColors.card,
                  border: isSelected
                      ? null
                      : Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _capitalize(e.key),
                      style: AppTypography.label.copyWith(
                        fontSize: 13,
                        color: isSelected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
