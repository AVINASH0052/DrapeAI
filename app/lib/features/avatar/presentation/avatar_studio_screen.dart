import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../wardrobe/models/item_model.dart';
import '../providers/avatar_studio_provider.dart';

class AvatarStudioScreen extends ConsumerWidget {
  const AvatarStudioScreen({super.key});

  Future<void> _render(WidgetRef ref, BuildContext context) async {
    final studio = ref.read(avatarStudioProvider);
    if (studio.selected.isEmpty) return;
    final notifier = ref.read(avatarStudioProvider.notifier);
    notifier.startRender();
    try {
      final slots =
          studio.selected.map((slot, item) => MapEntry(slot, item.id));
      final result = await ref.read(apiClientProvider).renderAvatar(slots);
      final immediate = result['preview_url'] as String?;
      if (result['status'] == 'completed' && immediate != null) {
        notifier.completeRender(Environment.resolveUrl(immediate));
        return;
      }

      final outfitId = result['outfit_id'] as String?;
      final jobId = result['job_id'] as String?;
      if (outfitId == null) {
        throw StateError('The render did not return an outfit ID.');
      }
      for (var attempt = 0; attempt < 120; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!context.mounted) return;
        final status = await ref
            .read(apiClientProvider)
            .avatarRenderStatus(outfitId, jobId: jobId);
        if (status['status'] == 'completed') {
          final url = status['preview_url'] as String?;
          if (url == null) throw StateError('The render image is missing.');
          notifier.completeRender(Environment.resolveUrl(url));
          return;
        }
        if (status['status'] == 'failed') {
          throw StateError(
            status['error_message'] as String? ??
                status['error'] as String? ??
                'The look could not be rendered.',
          );
        }
      }
      throw TimeoutException('The render is taking longer than expected.');
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map ? data['detail']?.toString() : null;
      notifier.failRender(detail ?? 'Could not render this look.');
    } catch (error) {
      notifier.failRender(
        error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studio = ref.watch(avatarStudioProvider);
    final wardrobe = ref.watch(avatarWardrobeProvider);
    final profile = ref.watch(userProfileProvider);
    final activeSlot = avatarSlots.firstWhere((s) => s.id == studio.activeSlot);
    final items = wardrobe.valueOrNull
            ?.where((item) =>
                item.processingStatus == 'ready' &&
                itemFitsAvatarSlot(item, studio.activeSlot))
            .toList() ??
        const <Item>[];
    final avatarUrl = profile.valueOrNull?.avatarBaseUrl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avatar studio',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Build a look from your closet',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Replace body photo',
                    onPressed: () => context.push('/body-setup'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                  ),
                  TextButton(
                    onPressed: studio.selected.isEmpty
                        ? null
                        : () => ref.read(avatarStudioProvider.notifier).reset(),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CategoryRail(
                      active: studio.activeSlot,
                      selected: studio.selected,
                      onSelect: (slot) => ref
                          .read(avatarStudioProvider.notifier)
                          .setActiveSlot(slot),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AvatarCanvas(
                        avatarUrl: avatarUrl,
                        previewUrl: studio.previewUrl,
                        selected: studio.selected,
                        isRendering: studio.isRendering,
                        onAddBody: () => context.push('/body-setup'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (studio.renderError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(78, 8, 16, 0),
                child: Text(
                  studio.renderError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.red, fontSize: 12),
                ),
              ),
            _SelectedChips(
              selected: studio.selected,
              onRemove: (slot) =>
                  ref.read(avatarStudioProvider.notifier).clearSlot(slot),
            ),
            _GarmentCarousel(
              slot: activeSlot,
              items: items,
              selectedId: studio.selected[studio.activeSlot]?.id,
              isLoading: wardrobe.isLoading,
              onSelect: (item) => ref
                  .read(avatarStudioProvider.notifier)
                  .toggleItem(studio.activeSlot, item),
              onAdd: () => context.push('/camera?returnTo=studio'),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                96 + MediaQuery.paddingOf(context).bottom,
              ),
              child: FilledButton.icon(
                onPressed: studio.selected.isEmpty || studio.isRendering
                    ? null
                    : () => _render(ref, context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: studio.isRendering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  studio.isRendering ? 'Rendering your look' : 'Try this look',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.active,
    required this.selected,
    required this.onSelect,
  });

  final String active;
  final Map<String, Item> selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColorsDark.border
              : AppColors.border,
        ),
      ),
      child: ListView(
        children: avatarSlots.map((slot) {
          final isActive = active == slot.id;
          return Tooltip(
            message: slot.label,
            child: InkWell(
              onTap: () => onSelect(slot.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      slot.icon,
                      size: 20,
                      color: isActive
                          ? Colors.white
                          : AppColors.textMuted(context),
                    ),
                    if (selected.containsKey(slot.id))
                      Positioned(
                        right: 5,
                        top: 6,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.lime,
                          ),
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
}

class _AvatarCanvas extends StatelessWidget {
  const _AvatarCanvas({
    required this.avatarUrl,
    required this.previewUrl,
    required this.selected,
    required this.isRendering,
    required this.onAddBody,
  });

  final String? avatarUrl;
  final String? previewUrl;
  final Map<String, Item> selected;
  final bool isRendering;
  final VoidCallback onAddBody;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEEE4), Color(0xFFF7E5D4)],
          ),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(28),
        ),
        child: avatarUrl == null
            ? Center(
                child: TextButton.icon(
                  onPressed: onAddBody,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add your body photo'),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: CachedNetworkImage(
                        imageUrl:
                            previewUrl ?? Environment.resolveUrl(avatarUrl!),
                        fit: BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  if (previewUrl == null)
                    ...selected.entries.map(
                      (entry) => _ApproximateGarment(
                          slot: entry.key, item: entry.value),
                    ),
                  if (isRendering)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Photorealistic preview is rendering',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ApproximateGarment extends StatelessWidget {
  const _ApproximateGarment({required this.slot, required this.item});

  final String slot;
  final Item item;

  @override
  Widget build(BuildContext context) {
    final settings = switch (slot) {
      'tops' => (Alignment(0, -0.34), 0.62, 0.46),
      'bottoms' => (Alignment(0, 0.3), 0.62, 0.52),
      'dresses' => (Alignment(0, 0.02), 0.72, 0.68),
      'outerwear' => (Alignment(0, -0.18), 0.7, 0.56),
      'footwear' => (Alignment(0, 0.92), 0.62, 0.2),
      'caps' => (Alignment(0, -0.92), 0.34, 0.18),
      'glasses' => (Alignment(0, -0.76), 0.3, 0.14),
      _ => (Alignment(0.62, 0), 0.35, 0.38),
    };
    return IgnorePointer(
      child: Align(
        alignment: settings.$1,
        child: FractionallySizedBox(
          widthFactor: settings.$2,
          heightFactor: settings.$3,
          child: Opacity(
            opacity: 0.76,
            child: CachedNetworkImage(
              imageUrl: Environment.resolveUrl(item.imageUrl),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({required this.selected, required this.onRemove});

  final Map<String, Item> selected;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (selected.isEmpty) return const SizedBox(height: 8);
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(78, 6, 16, 0),
        children: selected.entries.map((entry) {
          final slot = avatarSlots.firstWhere((s) => s.id == entry.key);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InputChip(
              visualDensity: VisualDensity.compact,
              label: Text(
                entry.value.displayName ??
                    entry.value.subCategory.ifEmpty(slot.label),
                style: const TextStyle(fontSize: 11),
              ),
              onDeleted: () => onRemove(entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GarmentCarousel extends StatelessWidget {
  const _GarmentCarousel({
    required this.slot,
    required this.items,
    required this.selectedId,
    required this.isLoading,
    required this.onSelect,
    required this.onAdd,
  });

  final AvatarSlot slot;
  final List<Item> items;
  final String? selectedId;
  final bool isLoading;
  final ValueChanged<Item> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            )
          : items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(78, 10, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label:
                        Text('Add ${slot.label.toLowerCase()} to your closet'),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(78, 8, 16, 0),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (_, index) {
                    if (index == items.length) {
                      return _AddGarmentTile(onTap: onAdd);
                    }
                    final item = items[index];
                    final active = item.id == selectedId;
                    return GestureDetector(
                      onTap: () => onSelect(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 76,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: active ? AppColors.orange : AppColors.border,
                            width: active ? 2.5 : 1,
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: Environment.resolveUrl(item.imageUrl),
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddGarmentTile extends StatelessWidget {
  const _AddGarmentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: 66,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.orange),
        ),
        child: const Icon(Icons.add_rounded, color: AppColors.orange),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
