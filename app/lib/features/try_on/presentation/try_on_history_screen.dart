import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';

class TryOnHistoryScreen extends ConsumerStatefulWidget {
  const TryOnHistoryScreen({super.key});

  @override
  ConsumerState<TryOnHistoryScreen> createState() => _TryOnHistoryScreenState();
}

class _TryOnHistoryScreenState extends ConsumerState<TryOnHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final resp = await ref.read(apiClientProvider).tryOnHistory();
    final sessions = resp['sessions'];
    if (sessions is List) {
      return sessions.cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your looks')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load history: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No completed external try-ons yet',
                style: AppTypography.caption,
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final s = items[i];
              final url = s['result_url'] as String?;
              return DrapeGlassCard(
                child: url == null
                    ? const SizedBox.shrink()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: Environment.resolveUrl(url),
                          fit: BoxFit.cover,
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
