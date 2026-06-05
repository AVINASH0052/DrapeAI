import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
    'All', 'Tops', 'Bottoms', 'Dresses', 'Outerwear', 'Ethnic', 'Footwear', 'Accessories'
  ];

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wardrobeProvider);
    final activeCategory = ref.watch(wardrobeCategoryFilter);

    // Watch the gratification provider and show dialog if triggered
    final shouldGratify =
        ref.watch(shouldShowGratificationProvider).valueOrNull ?? false;
    if (shouldGratify && !_gratificationHandled) {
      _gratificationHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GratificationDialog.present(context);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Wardrobe',
                        style: GoogleFonts.instrumentSerif(
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          color: AppColors.ink,
                        )),
                  ),
                  _IconBtn(
                    icon: Icons.search,
                    onTap: () => showSearch(
                      context: context,
                      delegate: _WardrobeSearchDelegate(ref),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _NotificationBell(ref: ref),
                ],
              ),
            ),
            // Filter chips
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isActive = activeCategory == _categories[i];
                  return GestureDetector(
                    onTap: () => ref.read(wardrobeCategoryFilter.notifier).state =
                        _categories[i],
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.ink : const Color(0xFFF1EFEB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _labels[i],
                        style: AppTypography.chip.copyWith(
                          color: isActive ? Colors.white : AppColors.ink2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Item count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: items.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${list.length} ITEMS',
                        style: AppTypography.mono.copyWith(
                            fontSize: 11, letterSpacing: 0.8)),
                    Text('Last added · Mar 20',
                        style: AppTypography.caption),
                  ],
                ),
              ),
            ),
            // Grid
            Expanded(
              child: items.when(
                loading: () => _buildSkeleton(),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load wardrobe', style: AppTypography.body),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(wardrobeProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (itemList) => itemList.isEmpty
                    ? _buildEmpty(context)
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(wardrobeProvider),
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.85,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('camera'),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.bgWarm,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checkroom_outlined,
                  size: 44, color: AppColors.ink3),
            ),
            const SizedBox(height: 18),
            Text('An empty closet.',
                style: AppTypography.displaySerif.copyWith(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              'Add your first item and we\'ll start suggesting outfits.',
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: () => context.pushNamed('camera'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add an item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.ink),
      ),
    );
  }
}

class _WardrobeSearchDelegate extends SearchDelegate<String> {
  final WidgetRef _ref;
  _WardrobeSearchDelegate(this._ref);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
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

class _NotificationBell extends StatelessWidget {
  final WidgetRef ref;
  const _NotificationBell({required this.ref});

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final count = unreadAsync.valueOrNull ?? 0;

    return GestureDetector(
      onTap: () => context.pushNamed('notifications'),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined,
                size: 20, color: AppColors.ink),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

