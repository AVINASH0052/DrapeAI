import 'dart:async';
import 'dart:ui';

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
import '../../try_on/widgets/try_on_refine_composer.dart';
import '../../wardrobe/models/item_model.dart';
import '../providers/avatar_studio_provider.dart';

String _previewPath(String url) {
  final q = url.indexOf('?');
  return q < 0 ? url : url.substring(0, q);
}

String _bustPreviewUrl(String url) {
  final base = _previewPath(url);
  return '$base?v=${DateTime.now().millisecondsSinceEpoch}';
}

class AvatarStudioScreen extends ConsumerStatefulWidget {
  const AvatarStudioScreen({super.key});

  @override
  ConsumerState<AvatarStudioScreen> createState() => _AvatarStudioScreenState();
}

class _AvatarStudioScreenState extends ConsumerState<AvatarStudioScreen> {
  bool _chromeHidden = false;
  bool _rightPanelOpen = false;
  final _refineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(avatarWardrobeProvider);
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _refineController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final data =
          await ref.read(apiClientProvider).avatarLookHistory(limit: 24);
      if (!mounted) return;
      final raw = data['looks'];
      if (raw is! List) return;
      final looks = raw
          .whereType<Map>()
          .map((e) => AvatarHistoryLook.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .map(
            (look) => AvatarHistoryLook(
              outfitId: look.outfitId,
              previewUrl: Environment.resolveUrl(look.previewUrl),
              slots: look.slots,
              pose: look.pose,
              style: look.style,
              quality: look.quality,
              fingerprint: look.fingerprint,
            ),
          )
          .toList();
      ref.read(avatarStudioProvider.notifier).setHistory(looks);
    } catch (_) {
      // History is optional — studio still works without it.
    }
  }

  Future<void> _deleteHistoryLook(AvatarHistoryLook look) async {
    try {
      await ref.read(apiClientProvider).deleteAvatarLook(look.outfitId);
      if (!mounted) return;
      ref.read(avatarStudioProvider.notifier).removeHistoryLook(look.outfitId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove that look.')),
      );
    }
  }

  void _restoreHistoryLook(AvatarHistoryLook look) {
    final wardrobe = ref.read(avatarWardrobeProvider).valueOrNull;
    if (wardrobe == null) return;
    final byId = {for (final item in wardrobe) item.id: item};
    final ok =
        ref.read(avatarStudioProvider.notifier).restoreHistoryLook(look, byId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some pieces from that look are no longer in your wardrobe.',
          ),
        ),
      );
      return;
    }
    setState(() => _chromeHidden = true);
  }

  Future<void> _render(BuildContext context) async {
    final studio = ref.read(avatarStudioProvider);
    if (studio.selected.isEmpty) return;

    final local = studio.renderCache[studio.currentFingerprint];
    final showingSaved = local != null &&
        studio.previewUrl != null &&
        _previewPath(studio.previewUrl!) == _previewPath(local.previewUrl);

    // Cached look is not what is on screen — show it. Tap again to regenerate.
    if (local != null && !showingSaved) {
      ref.read(avatarStudioProvider.notifier).completeRender(
            _bustPreviewUrl(local.previewUrl),
            outfitId: local.outfitId,
          );
      if (mounted) setState(() => _chromeHidden = true);
      return;
    }

    final notifier = ref.read(avatarStudioProvider.notifier);
    notifier.startRender();
    try {
      final slots =
          studio.selected.map((slot, item) => MapEntry(slot, item.id));
      final result = await ref.read(apiClientProvider).renderAvatar(
            slots,
            pose: studio.pose,
            style: studio.style,
            quality: studio.quality,
            force: showingSaved,
          );
      final immediate = result['preview_url'] as String?;
      final outfitIdImmediate = result['outfit_id'] as String?;
      if (result['status'] == 'completed' && immediate != null) {
        notifier.completeRender(
          _bustPreviewUrl(Environment.resolveUrl(immediate)),
          outfitId: outfitIdImmediate,
        );
        if (mounted) setState(() => _chromeHidden = true);
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
          notifier.completeRender(
            _bustPreviewUrl(Environment.resolveUrl(url)),
            outfitId: outfitId,
          );
          if (mounted) setState(() => _chromeHidden = true);
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

  Future<void> _refineLook() async {
    final message = _refineController.text.trim();
    final studio = ref.read(avatarStudioProvider);
    final outfitId = studio.outfitId;
    if (message.isEmpty || outfitId == null || studio.isRendering) return;

    final notifier = ref.read(avatarStudioProvider.notifier);
    notifier.startRender();
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.refineVisualize(outfitId, message);
      final immediate = result['preview_url'] as String?;
      if (result['status'] == 'completed' && immediate != null) {
        notifier.completeRender(
          _bustPreviewUrl(Environment.resolveUrl(immediate)),
          outfitId: outfitId,
        );
        _refineController.clear();
        if (mounted) setState(() => _chromeHidden = true);
        return;
      }

      final jobId = result['job_id'] as String?;
      for (var attempt = 0; attempt < 120; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        final status =
            await api.avatarRenderStatus(outfitId, jobId: jobId);
        if (status['status'] == 'completed') {
          final url = status['preview_url'] as String?;
          if (url == null) throw StateError('The refined image is missing.');
          notifier.completeRender(
            _bustPreviewUrl(Environment.resolveUrl(url)),
            outfitId: outfitId,
          );
          _refineController.clear();
          if (mounted) setState(() => _chromeHidden = true);
          return;
        }
        if (status['status'] == 'failed') {
          throw StateError(
            status['error'] as String? ?? 'Could not refine this look.',
          );
        }
      }
      throw TimeoutException('Refine is taking longer than expected.');
    } on DioException catch (error) {
      final data = error.response?.data;
      String? detail;
      if (data is Map) {
        final d = data['detail'];
        if (d is Map && d['message'] != null) {
          detail = d['message'].toString();
        } else if (d != null) {
          detail = d.toString();
        }
      }
      notifier.failRender(detail ?? 'Could not refine this look.');
    } catch (error) {
      notifier.failRender(
        error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  String _pretty(String value) =>
      value.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        if (w == 'hd') return 'HD';
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(avatarStudioProvider);
    final wardrobe = ref.watch(avatarWardrobeProvider);
    final profile = ref.watch(userProfileProvider);
    final activeSlot = avatarSlots.firstWhere((s) => s.id == studio.activeSlot);
    final readyItems = wardrobe.valueOrNull
            ?.where((item) => item.processingStatus == 'ready')
            .toList() ??
        const <Item>[];
    ref.listen(avatarWardrobeProvider, (_, next) {
      final ids = next.valueOrNull?.map((i) => i.id).toSet();
      if (ids != null) {
        ref.read(avatarStudioProvider.notifier).pruneMissing(ids);
      }
    });
    final items = readyItems
        .where((item) => itemFitsAvatarSlot(item, studio.activeSlot))
        .toList();
    final stageUrl =
        profile.valueOrNull?.tryOnPhotoUrl ?? profile.valueOrNull?.avatarBaseUrl;
    final topPad = MediaQuery.paddingOf(context).top;
    final hasHistory = studio.history.isNotEmpty;
    final bottomPad =
        (hasHistory ? 148 : 88) + MediaQuery.paddingOf(context).bottom;
    final cachedLook = studio.renderCache[studio.currentFingerprint];
    final lookAlreadySaved = cachedLook != null &&
        studio.previewUrl != null &&
        _previewPath(studio.previewUrl!) == _previewPath(cachedLook.previewUrl);

    return Scaffold(
      backgroundColor: const Color(0xFF120E0C),
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Avatar fills the screen — center stays clear
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_rightPanelOpen) {
                  setState(() => _rightPanelOpen = false);
                  return;
                }
                if (studio.previewUrl != null) {
                  setState(() => _chromeHidden = !_chromeHidden);
                }
              },
              child: _FullScreenAvatar(
                avatarUrl: stageUrl,
                previewUrl: studio.previewUrl,
                isRendering: studio.isRendering,
                onAddBody: () => context.push('/body-setup'),
              ),
            ),
          ),

          if (!_chromeHidden) ...[
            // Soft edge fades only — not a big mid-card
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 110,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 200,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top title — light
            Positioned(
              top: topPad + 4,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Studio',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  _SideIcon(
                    icon: Icons.person_outline_rounded,
                    tooltip: 'Replace body photo',
                    onTap: () => context.push('/body-setup'),
                  ),
                  const SizedBox(width: 8),
                  _SideIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Clear selection',
                    enabled: studio.selected.isNotEmpty,
                    onTap: studio.selected.isEmpty
                        ? null
                        : () =>
                            ref.read(avatarStudioProvider.notifier).reset(),
                  ),
                ],
              ),
            ),

            // LEFT — categories
            Positioned(
              left: 10,
              top: topPad + 56,
              bottom: bottomPad + 108,
              child: _LeftCategoryRail(
                active: studio.activeSlot,
                selected: studio.selected,
                onSelect: (slot) =>
                    ref.read(avatarStudioProvider.notifier).setActiveSlot(slot),
              ),
            ),

            // RIGHT — look options + selected pieces
            Positioned(
              right: 10,
              top: topPad + 56,
              bottom: bottomPad + 108,
              child: _RightOptionsRail(
                studio: studio,
                panelOpen: _rightPanelOpen,
                pretty: _pretty,
                onTogglePanel: () =>
                    setState(() => _rightPanelOpen = !_rightPanelOpen),
                onPose: (v) =>
                    ref.read(avatarStudioProvider.notifier).setPose(v),
                onStyle: (v) =>
                    ref.read(avatarStudioProvider.notifier).setStyle(v),
                onQuality: (v) =>
                    ref.read(avatarStudioProvider.notifier).setQuality(v),
                onClearSlot: (slot) =>
                    ref.read(avatarStudioProvider.notifier).clearSlot(slot),
              ),
            ),

            // BOTTOM — previous looks + garments + CTA
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomPad,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasHistory)
                    _HistoryStrip(
                      looks: studio.history,
                      activeOutfitId: studio.outfitId,
                      onSelect: _restoreHistoryLook,
                      onDelete: _deleteHistoryLook,
                    ),
                  _BottomStrip(
                    slot: activeSlot,
                    items: items,
                    selectedId: studio.selected[studio.activeSlot]?.id,
                    isLoading: wardrobe.isLoading,
                    canRender: studio.selected.isNotEmpty,
                    isRendering: studio.isRendering,
                    lookAlreadySaved: lookAlreadySaved,
                    error: studio.renderError,
                    onSelect: (item) => ref
                        .read(avatarStudioProvider.notifier)
                        .toggleItem(studio.activeSlot, item),
                    onAdd: () => context.push('/camera?returnTo=studio'),
                    onRender: () => _render(context),
                  ),
                ],
              ),
            ),
          ],

          if (_chromeHidden && studio.previewUrl != null)
            Positioned(
              top: topPad + 10,
              right: 14,
              child: _SideIcon(
                icon: Icons.tune_rounded,
                tooltip: 'Show controls',
                onTap: () => setState(() => _chromeHidden = false),
              ),
            ),

          // Only in preview mode. On the dresser it sat on Try this look.
          if (_chromeHidden &&
              studio.previewUrl != null &&
              studio.outfitId != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: Material(
                color: const Color(0xCC120E0C),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: TryOnRefineComposer(
                    controller: _refineController,
                    enabled: !studio.isRendering,
                    onSubmit: _refineLook,
                    onDark: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Left rail: categories ───────────────────────────────────────────────────

class _LeftCategoryRail extends StatelessWidget {
  const _LeftCategoryRail({
    required this.active,
    required this.selected,
    required this.onSelect,
  });

  final String active;
  final Map<String, Item> selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      width: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: avatarSlots.map((slot) {
          final isActive = active == slot.id;
          final filled = selected.containsKey(slot.id);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Tooltip(
              message: slot.label,
              child: InkWell(
                onTap: () => onSelect(slot.id),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 42,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        slot.icon,
                        size: 20,
                        color: isActive ? Colors.white : Colors.white70,
                      ),
                      if (filled)
                        Positioned(
                          right: 6,
                          top: 7,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? Colors.white : AppColors.lime,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Right rail: look settings + selected ────────────────────────────────────

class _RightOptionsRail extends StatelessWidget {
  const _RightOptionsRail({
    required this.studio,
    required this.panelOpen,
    required this.pretty,
    required this.onTogglePanel,
    required this.onPose,
    required this.onStyle,
    required this.onQuality,
    required this.onClearSlot,
  });

  final AvatarStudioState studio;
  final bool panelOpen;
  final String Function(String) pretty;
  final VoidCallback onTogglePanel;
  final ValueChanged<String> onPose;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onQuality;
  final ValueChanged<String> onClearSlot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (panelOpen)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LookSettingsPanel(
              pose: studio.pose,
              style: studio.style,
              quality: studio.quality,
              onPose: onPose,
              onStyle: onStyle,
              onQuality: onQuality,
            ),
          ),
        _GlassPill(
          width: 52,
          child: Column(
            children: [
              const SizedBox(height: 6),
              _RailAction(
                icon: Icons.tune_rounded,
                tooltip: 'Pose · style · quality',
                active: panelOpen,
                onTap: onTogglePanel,
              ),
              _RailAction(
                icon: Icons.accessibility_new_rounded,
                tooltip: 'Pose: ${pretty(studio.pose)}',
                onTap: onTogglePanel,
              ),
              _RailAction(
                icon: Icons.wb_sunny_outlined,
                tooltip: 'Style: ${pretty(studio.style)}',
                onTap: onTogglePanel,
              ),
              _RailAction(
                icon: Icons.high_quality_outlined,
                tooltip: 'Quality: ${pretty(studio.quality)}',
                active: studio.quality == 'hd' && !panelOpen,
                badge: studio.quality == 'hd' ? 'HD' : null,
                onTap: onTogglePanel,
              ),
              if (studio.selected.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white24,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: studio.selected.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                        child: GestureDetector(
                          onTap: () => onClearSlot(entry.key),
                          child: Tooltip(
                            message: 'Remove ${entry.key}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColoredBox(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      child: CachedNetworkImage(
                                        imageUrl: Environment.resolveUrl(
                                          entry.value.imageUrl,
                                        ),
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white30,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LookSettingsPanel extends StatelessWidget {
  const _LookSettingsPanel({
    required this.pose,
    required this.style,
    required this.quality,
    required this.onPose,
    required this.onStyle,
    required this.onQuality,
  });

  final String pose;
  final String style;
  final String quality;
  final ValueChanged<String> onPose;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onQuality;

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      width: 132,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SideOptionGroup(
              title: 'Pose',
              values: avatarPoses,
              selected: pose,
              onSelect: onPose,
            ),
            const SizedBox(height: 12),
            _SideOptionGroup(
              title: 'Style',
              values: avatarStyles,
              selected: style,
              onSelect: onStyle,
            ),
            const SizedBox(height: 12),
            _SideOptionGroup(
              title: 'Quality',
              values: avatarQualities,
              selected: quality,
              onSelect: onQuality,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideOptionGroup extends StatelessWidget {
  const _SideOptionGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelect;

  String _pretty(String value) =>
      value.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        if (w == 'hd') return 'HD';
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        ...values.map((value) {
          final active = value == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: () => onSelect(value),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.orange : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _pretty(value),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 42,
            decoration: BoxDecoration(
              color: active ? AppColors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                if (badge != null)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      badge!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : AppColors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom strip ────────────────────────────────────────────────────────────

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({
    required this.looks,
    required this.activeOutfitId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<AvatarHistoryLook> looks;
  final String? activeOutfitId;
  final ValueChanged<AvatarHistoryLook> onSelect;
  final ValueChanged<AvatarHistoryLook> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Previous looks',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: looks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final look = looks[index];
                final active = look.outfitId == activeOutfitId;
                return SizedBox(
                  width: 48,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => onSelect(look),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 48,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? AppColors.orange : Colors.white24,
                              width: active ? 2 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: look.previewUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: GestureDetector(
                          onTap: () => onDelete(look),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xE6120E0C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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

class _BottomStrip extends StatelessWidget {
  const _BottomStrip({
    required this.slot,
    required this.items,
    required this.selectedId,
    required this.isLoading,
    required this.canRender,
    required this.isRendering,
    required this.lookAlreadySaved,
    required this.error,
    required this.onSelect,
    required this.onAdd,
    required this.onRender,
  });

  final AvatarSlot slot;
  final List<Item> items;
  final String? selectedId;
  final bool isLoading;
  final bool canRender;
  final bool isRendering;
  final bool lookAlreadySaved;
  final String? error;
  final ValueChanged<Item> onSelect;
  final VoidCallback onAdd;
  final VoidCallback onRender;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(68, 0, 68, 6),
            child: Text(
              error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFF8A80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        SizedBox(
          height: 78,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.orange,
                    ),
                  ),
                )
              : items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 68),
                      child: OutlinedButton.icon(
                        onPressed: onAdd,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                        label: Text(
                          'Add ${slot.label.toLowerCase()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(68, 0, 68, 0),
                      itemCount: items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        if (index == items.length) {
                          return _AddTile(onTap: onAdd);
                        }
                        final item = items[index];
                        final active = item.id == selectedId;
                        return GestureDetector(
                          onTap: () => onSelect(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 64,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? AppColors.orange
                                    : Colors.white.withValues(alpha: 0.2),
                                width: active ? 2 : 1,
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
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 68),
          child: SizedBox(
            height: 46,
            width: double.infinity,
            child: FilledButton(
              onPressed: !canRender || isRendering ? null : onRender,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                disabledBackgroundColor:
                    AppColors.orange.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isRendering
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rendering',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      !canRender
                          ? 'Pick a piece'
                          : lookAlreadySaved
                              ? 'Try this look again'
                              : 'Try this look',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange),
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: const Icon(Icons.add_rounded, color: AppColors.orange),
      ),
    );
  }
}

// ─── Shared chrome ───────────────────────────────────────────────────────────

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SideIcon extends StatelessWidget {
  const _SideIcon({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.16 : 0.06),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
          ),
        ),
      ),
    );
  }
}

class _FullScreenAvatar extends StatelessWidget {
  const _FullScreenAvatar({
    required this.avatarUrl,
    required this.previewUrl,
    required this.isRendering,
    required this.onAddBody,
  });

  final String? avatarUrl;
  final String? previewUrl;
  final bool isRendering;
  final VoidCallback onAddBody;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null) {
      return ColoredBox(
        color: const Color(0xFF120E0C),
        child: Center(
          child: TextButton.icon(
            onPressed: onAddBody,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              'Add your body photo',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C241E),
                Color(0xFF171310),
                Color(0xFF0C0908),
              ],
            ),
          ),
        ),
        InteractiveViewer(
          minScale: 1,
          maxScale: 3.5,
          child: CachedNetworkImage(
            imageUrl: previewUrl ?? Environment.resolveUrl(avatarUrl!),
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.12),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54),
            ),
          ),
        ),
        if (isRendering)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 56,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Crafting look',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
