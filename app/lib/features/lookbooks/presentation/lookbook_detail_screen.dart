import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../outfits/models/outfit_model.dart';
import '../../outfits/widgets/outfit_card.dart';

class LookbookDetailScreen extends ConsumerStatefulWidget {
  final String lookbookId;
  const LookbookDetailScreen({required this.lookbookId, super.key});

  @override
  ConsumerState<LookbookDetailScreen> createState() =>
      _LookbookDetailScreenState();
}

class _LookbookDetailScreenState
    extends ConsumerState<LookbookDetailScreen> {
  Map<String, dynamic>? _lookbook;
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
      final data = await api.getLookbook(widget.lookbookId);
      setState(() => _lookbook = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }
    if (_lookbook == null) {
      return Scaffold(
        body: Center(child: Text('Lookbook not found',
            style: AppTypography.body)),
      );
    }

    final name = _lookbook!['name'] ?? '';
    final outfits =
        List<Map<String, dynamic>>.from(_lookbook!['outfits'] ?? []);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.instrumentSerif(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              color: AppColors.ink,
                            )),
                        Text('${outfits.length} outfits · curated',
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.share_outlined, size: 18,
                          color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: outfits.isEmpty
                  ? Center(
                      child: Text('No outfits in this lookbook yet',
                          style: AppTypography.body))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: outfits.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        final outfit = Outfit.fromJson(outfits[i]);
                        return OutfitCard(outfit: outfit);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
