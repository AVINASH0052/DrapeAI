import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../outfits/models/outfit_model.dart';
import '../providers/calendar_provider.dart';

/// Pick a saved/today outfit to assign to a calendar date.
class CalendarAssignSheet extends ConsumerStatefulWidget {
  final String dateIso;
  const CalendarAssignSheet({required this.dateIso, super.key});

  @override
  ConsumerState<CalendarAssignSheet> createState() =>
      _CalendarAssignSheetState();
}

class _CalendarAssignSheetState extends ConsumerState<CalendarAssignSheet> {
  List<Outfit> _outfits = [];
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
      final today = await api.getTodayOutfits();
      final outfits = (today['outfits'] as List? ?? [])
          .map((j) => Outfit.fromJson(j as Map<String, dynamic>))
          .toList();

      if (outfits.isEmpty) {
        final lookbooks = await api.getLookbooks();
        for (final lb in (lookbooks['lookbooks'] as List? ?? [])) {
          final detail =
              await api.getLookbook(lb['id'] as String);
          for (final o in (detail['outfits'] as List? ?? [])) {
            outfits.add(Outfit.fromJson(o as Map<String, dynamic>));
          }
        }
      }

      if (mounted) {
        setState(() {
          _outfits = outfits;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _assign(Outfit outfit) async {
    try {
      await ref.read(apiClientProvider).assignOutfitToDate(
            widget.dateIso,
            outfit.id,
          );
      final month = widget.dateIso.substring(0, 7);
      ref.invalidate(calendarEntriesProvider(month));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Plan outfit · ${widget.dateIso}',
              style: AppTypography.headingSerif.copyWith(fontSize: 22),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _outfits.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: DrapeGlassCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('No saved outfits yet',
                                      style: AppTypography.title),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Generate outfits on Today or Shuffle, then come back.',
                                    style: AppTypography.body,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _outfits.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final o = _outfits[i];
                              return DrapeGlassCard(
                                onTap: () => _assign(o),
                                child: Row(
                                  children: [
                                    ...o.items.take(3).map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: Environment.resolveUrl(
                                                item.imageUrl),
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    }),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        o.occasion.toUpperCase(),
                                        style: AppTypography.chip,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

void showCalendarAssignSheet(BuildContext context, String dateIso) {
  showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CalendarAssignSheet(dateIso: dateIso),
  );
}
