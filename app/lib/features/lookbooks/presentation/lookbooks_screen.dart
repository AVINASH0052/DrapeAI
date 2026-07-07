import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/drape_ui.dart';

class LookbooksScreen extends ConsumerStatefulWidget {
  const LookbooksScreen({super.key});

  @override
  ConsumerState<LookbooksScreen> createState() => _LookbooksScreenState();
}

class _LookbooksScreenState extends ConsumerState<LookbooksScreen> {
  List<Map<String, dynamic>> _lookbooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getLookbooks();
      setState(() => _lookbooks =
          List<Map<String, dynamic>>.from(data['lookbooks']));
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _createLookbook() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.bg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: Text('New lookbook',
              style: GoogleFonts.instrumentSerif(fontSize: 22)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Lookbook name'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(color: AppColors.ink3))),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('Create',
                  style: TextStyle(color: AppColors.orange,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(apiClientProvider).createLookbook(name);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              DrapeScreenHeader(
                title: 'Moodboards',
                subtitle: 'saved fits, curated vibes',
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.add_rounded,
                    onTap: _createLookbook,
                  ),
                ],
              ),
              const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.orange))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: _lookbooks.length + 1,
                        itemBuilder: (_, i) {
                          if (i == _lookbooks.length) {
                            return _buildNewCard();
                          }
                          return _buildLookbookCard(_lookbooks[i]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLookbookCard(Map<String, dynamic> lb) {
    return GestureDetector(
      onTap: () => context.pushNamed(
        'lookbook_detail',
        pathParameters: {'id': lb['id']},
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.bgWarm),
            // Dark gradient overlay at bottom
            Positioned(
              left: 0, right: 0, bottom: 0, height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14, right: 14, bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lb['name'] ?? '',
                    style: GoogleFonts.instrumentSerif(
                      fontSize: 22, color: Colors.white, height: 1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lb['outfit_count'] ?? 0} OUTFITS',
                    style: AppTypography.mono.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewCard() {
    return GestureDetector(
      onTap: _createLookbook,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: AppColors.borderStrong,
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 26, color: AppColors.ink3),
            const SizedBox(height: 8),
            Text('New lookbook',
                style: AppTypography.caption.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
