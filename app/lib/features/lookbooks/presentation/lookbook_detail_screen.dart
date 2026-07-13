import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/drape_ui.dart';
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
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              DrapeScreenHeader(
                title: name,
                subtitle: '${outfits.length} outfits · curated',
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                ],
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
      ),
    );
  }
}
