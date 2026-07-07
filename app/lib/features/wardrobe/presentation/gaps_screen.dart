import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

class GapsScreen extends ConsumerStatefulWidget {
  const GapsScreen({super.key});

  @override
  ConsumerState<GapsScreen> createState() => _GapsScreenState();
}

class _GapsScreenState extends ConsumerState<GapsScreen> {
  List<Map<String, dynamic>> _gaps = [];
  int _totalItems = 0;
  String? _message;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getWardrobeGaps();
      setState(() {
        _gaps =
            List<Map<String, dynamic>>.from(data['gaps'] ?? const []);
        _totalItems = (data['total_items'] as num?)?.toInt() ?? 0;
        _message = data['message'] as String?;
      });
    } catch (e) {
      setState(() => _error = e.toString().split('\n').first);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                      child: const Icon(Icons.arrow_back,
                          size: 20, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wardrobe gaps',
                            style: GoogleFonts.instrumentSerif(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              color: AppColors.ink,
                            )),
                        Text(
                            _totalItems > 0
                                ? 'What categories are light in your closet'
                                : 'Suggestions based on your style profile',
                            style: AppTypography.caption),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _loading ? null : _load,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.refresh,
                          size: 18, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.orange),
            const SizedBox(height: 14),
            Text('Analyzing your wardrobe…',
                style: AppTypography.body),
            const SizedBox(height: 4),
            Text('This usually takes a few seconds',
                style: AppTypography.caption),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not analyze wardrobe',
                style: AppTypography.body),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_gaps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _message ?? 'Looks balanced — no urgent gaps right now.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: _gaps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final g = _gaps[i];
        final priority = (g['priority'] as num?)?.toInt() ?? 3;
        return _GapCard(
          item: g['item'] ?? '',
          category: g['category'] ?? '',
          reason: g['reason'] ?? '',
          priority: priority,
          priceRange: g['est_price_range_inr'] ?? '',
        );
      },
    );
  }
}

class _GapCard extends StatelessWidget {
  final String item;
  final String category;
  final String reason;
  final int priority;
  final String priceRange;

  const _GapCard({
    required this.item,
    required this.category,
    required this.reason,
    required this.priority,
    required this.priceRange,
  });

  Color get _priorityColor =>
      priority <= 2 ? AppColors.orange : AppColors.ink3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
              height: 2,
              decoration: BoxDecoration(color: _priorityColor)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _priorityColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('P$priority',
                          style: AppTypography.mono.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(category.toUpperCase(),
                        style: AppTypography.mono.copyWith(
                            fontSize: 10,
                            color: AppColors.ink2,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    if (priceRange.isNotEmpty)
                      Text(priceRange,
                          style: AppTypography.mono.copyWith(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item,
                    style: GoogleFonts.instrumentSerif(
                        fontSize: 22, color: AppColors.ink, height: 1.1)),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(reason,
                      style: AppTypography.body.copyWith(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
