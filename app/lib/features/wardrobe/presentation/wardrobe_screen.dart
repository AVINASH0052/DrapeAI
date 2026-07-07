import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../widgets/gratification_dialog.dart';
import '../widgets/item_card.dart';

class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  bool _gratificationHandled = false;

  static const _categories = <String?>[
    null, 'top', 'bottom', 'dress', 'outer', 'ethnic', 'footwear', 'accessory'
  ];
  static const _labels = [
    'All', 'Tops', 'Bottoms', 'Dresses', 'Outer', 'Ethnic', 'Kicks', 'Extras'
  ];

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wardrobeProvider);
    final activeCategory = ref.watch(wardrobeCategoryFilter);
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    final shouldGratify =
        ref.watch(shouldShowGratificationProvider).valueOrNull ?? false;
    if (shouldGratify && !_gratificationHandled) {
      _gratificationHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GratificationDialog.present(context);
      });
    }

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DrapeScreenHeader(
                title: 'Closet',
                subtitle: 'every piece. one vibe.',
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.search_rounded,
                    onTap: () => showSearch(
                      context: context,
                      delegate: _WardrobeSearchDelegate(ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DrapeIconButton(
                    icon: Icons.notifications_none_rounded,
                    badge: unread,
                    onTap: () => context.pushNamed('notifications'),
                  ),
                ],
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => DrapeChip(
                    label: _labels[i],
                    active: activeCategory == _categories[i],
                    onTap: () => ref.read(wardrobeCategoryFilter.notifier).state =
                        _categories[i],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: items.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${list.length} PIECES',
                        style: AppTypography.mono.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                      if (list.isNotEmpty)
                        Text(
                          'latest · ${DateFormat('MMM d').format(list.first.createdAt)}',
                          style: AppTypography.caption,
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: items.when(
                  loading: () => _buildSkeleton(context),
                  error: (e, _) => Center(
                    child: DrapeGlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('😵', style: TextStyle(fontSize: 32)),
                          const SizedBox(height: 12),
                          Text('closet didn\'t load',
                              style: AppTypography.title),
                          const SizedBox(height: 8),
                          Text('check connection & retry',
                              style: AppTypography.body),
                          const SizedBox(height: 16),
                          DrapeGradientButton(
                            label: 'Try again',
                            onPressed: () => ref.invalidate(wardrobeProvider),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (itemList) => itemList.isEmpty
                      ? _buildEmpty(context)
                      : RefreshIndicator(
                          color: AppColors.orange,
                          onRefresh: () async =>
                              ref.invalidate(wardrobeProvider),
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: itemList.length,
                            itemBuilder: (_, i) => ItemCard(
                              item: itemList[i],
                              onTap: () => context.pushNamed(
                                'item_detail',
                                pathParameters: {'id': itemList[i].id},
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.cta,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.pushNamed('camera'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.gray100 : AppColors.gray100,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: DrapeGlassCard(
          gradientBorder: true,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👗', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'empty closet energy',
                style: AppTypography.headingSerif.copyWith(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'snap your first fit. AI tags it. we style you in 3 uploads.',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
              const SizedBox(height: 20),
              DrapeGradientButton(
                label: 'Add first piece',
                icon: Icons.camera_alt_rounded,
                onPressed: () => context.pushNamed('camera'),
              ),
              const SizedBox(height: 10),
              DrapeGradientButton(
                label: 'Try demo wardrobe',
                onPressed: () => _activateDemo(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _activateDemo(BuildContext context) async {
    try {
      final result = await ref.read(apiClientProvider).activateDemoWardrobe();
      ref.invalidate(wardrobeProvider);
      if (!context.mounted) return;
      final added = result['items_added'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? 'Demo wardrobe loaded — $added pieces'
                : 'Demo wardrobe ready',
          ),
          backgroundColor: AppColors.lime,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo load failed: $e')),
      );
    }
  }
}

class _WardrobeSearchDelegate extends SearchDelegate<String> {
  final WidgetRef _ref;
  _WardrobeSearchDelegate(this._ref);

  @override
  String get searchFieldLabel => 'search your closet…';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) {
    _ref.read(wardrobeSearchQuery.notifier).state = query;
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox.shrink();
}
