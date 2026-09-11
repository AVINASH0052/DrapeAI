import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../wardrobe/models/item_model.dart';

class AvatarSlot {
  const AvatarSlot(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const avatarSlots = [
  AvatarSlot('tops', 'Tops', Icons.checkroom_outlined),
  AvatarSlot('bottoms', 'Bottoms', Icons.view_agenda_outlined),
  AvatarSlot('dresses', 'Dresses', Icons.woman_2_outlined),
  AvatarSlot('outerwear', 'Layers', Icons.dry_cleaning_outlined),
  AvatarSlot('footwear', 'Shoes', Icons.ice_skating_outlined),
  AvatarSlot('accessories', 'Extras', Icons.watch_outlined),
  AvatarSlot('caps', 'Caps', Icons.sports_baseball_outlined),
  AvatarSlot('glasses', 'Glasses', Icons.visibility_outlined),
];

const avatarPoses = ['natural', 'standing', 'walking', 'three_quarter'];
const avatarStyles = ['studio', 'street', 'festive', 'editorial'];
const avatarQualities = ['standard', 'hd'];

/// Fresh fetch each time Studio is opened (autoDispose) so uploads/deletes show up.
final avatarWardrobeProvider =
    FutureProvider.autoDispose<List<Item>>((ref) async {
  final data = await ref.read(apiClientProvider).getItems(limit: 200);
  return (data['items'] as List)
      .map((json) => Item.fromJson(json as Map<String, dynamic>))
      .toList();
});

class CachedLook {
  const CachedLook({
    required this.previewUrl,
    required this.outfitId,
  });

  final String previewUrl;
  final String outfitId;
}

class AvatarHistoryLook {
  const AvatarHistoryLook({
    required this.outfitId,
    required this.previewUrl,
    required this.slots,
    required this.pose,
    required this.style,
    required this.quality,
    this.fingerprint,
  });

  final String outfitId;
  final String previewUrl;
  final Map<String, String> slots;
  final String pose;
  final String style;
  final String quality;
  final String? fingerprint;

  factory AvatarHistoryLook.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    final slots = <String, String>{};
    if (rawSlots is Map) {
      rawSlots.forEach((key, value) {
        if (value != null) slots[key.toString()] = value.toString();
      });
    }
    return AvatarHistoryLook(
      outfitId: json['outfit_id'] as String,
      previewUrl: json['preview_url'] as String,
      slots: slots,
      pose: (json['pose'] as String?) ?? 'natural',
      style: (json['style'] as String?) ?? 'studio',
      quality: (json['quality'] as String?) ?? 'hd',
      fingerprint: json['fingerprint'] as String?,
    );
  }
}

/// Client fingerprint (slots + pose/style/quality). Server also keys on body photo.
String avatarLookFingerprint({
  required Map<String, Item> selected,
  required String pose,
  required String style,
  required String quality,
}) {
  final slotBits = <String>[];
  for (final slot in avatarSlots) {
    final item = selected[slot.id];
    if (item != null) slotBits.add('${slot.id}=${item.id}');
  }
  return [
    'v1',
    'pose=${pose.trim().toLowerCase()}',
    'style=${style.trim().toLowerCase()}',
    'quality=${quality.trim().toLowerCase()}',
    ...slotBits,
  ].join('|');
}

class AvatarStudioState {
  const AvatarStudioState({
    this.activeSlot = 'tops',
    this.selected = const {},
    this.previewUrl,
    this.outfitId,
    this.isRendering = false,
    this.renderError,
    this.pose = 'natural',
    this.style = 'studio',
    this.quality = 'hd',
    this.renderCache = const {},
    this.history = const [],
  });

  final String activeSlot;
  final Map<String, Item> selected;
  final String? previewUrl;
  final String? outfitId;
  final bool isRendering;
  final String? renderError;
  final String pose;
  final String style;
  final String quality;
  final Map<String, CachedLook> renderCache;
  final List<AvatarHistoryLook> history;

  String get currentFingerprint => avatarLookFingerprint(
        selected: selected,
        pose: pose,
        style: style,
        quality: quality,
      );

  AvatarStudioState copyWith({
    String? activeSlot,
    Map<String, Item>? selected,
    String? previewUrl,
    bool clearPreview = false,
    String? outfitId,
    bool clearOutfitId = false,
    bool? isRendering,
    String? renderError,
    bool clearError = false,
    String? pose,
    String? style,
    String? quality,
    Map<String, CachedLook>? renderCache,
    List<AvatarHistoryLook>? history,
  }) {
    return AvatarStudioState(
      activeSlot: activeSlot ?? this.activeSlot,
      selected: selected ?? this.selected,
      previewUrl: clearPreview ? null : (previewUrl ?? this.previewUrl),
      outfitId: clearOutfitId
          ? null
          : (outfitId ?? (clearPreview ? null : this.outfitId)),
      isRendering: isRendering ?? this.isRendering,
      renderError: clearError ? null : (renderError ?? this.renderError),
      pose: pose ?? this.pose,
      style: style ?? this.style,
      quality: quality ?? this.quality,
      renderCache: renderCache ?? this.renderCache,
      history: history ?? this.history,
    );
  }
}

final avatarStudioProvider =
    StateNotifierProvider<AvatarStudioNotifier, AvatarStudioState>((ref) {
  return AvatarStudioNotifier();
});

class AvatarStudioNotifier extends StateNotifier<AvatarStudioState> {
  AvatarStudioNotifier() : super(const AvatarStudioState());

  void setActiveSlot(String slot) {
    state = state.copyWith(activeSlot: slot, clearError: true);
  }

  void setPose(String pose) {
    _applyLookOptions(pose: pose);
  }

  void setStyle(String style) {
    _applyLookOptions(style: style);
  }

  void setQuality(String quality) {
    _applyLookOptions(quality: quality);
  }

  void _applyLookOptions({String? pose, String? style, String? quality}) {
    final nextPose = pose ?? state.pose;
    final nextStyle = style ?? state.style;
    final nextQuality = quality ?? state.quality;
    final fp = avatarLookFingerprint(
      selected: state.selected,
      pose: nextPose,
      style: nextStyle,
      quality: nextQuality,
    );
    final cached = state.renderCache[fp];
    state = state.copyWith(
      pose: nextPose,
      style: nextStyle,
      quality: nextQuality,
      previewUrl: cached?.previewUrl,
      outfitId: cached?.outfitId,
      clearPreview: cached == null,
      clearError: true,
    );
  }

  void toggleItem(String slot, Item item) {
    final next = Map<String, Item>.from(state.selected);
    if (next[slot]?.id == item.id) {
      next.remove(slot);
    } else {
      if (slot == 'dresses') {
        next.remove('tops');
        next.remove('bottoms');
      } else if (slot == 'tops' || slot == 'bottoms') {
        next.remove('dresses');
      }
      next[slot] = item;
    }
    _setSelection(next);
  }

  void clearSlot(String slot) {
    final next = Map<String, Item>.from(state.selected)..remove(slot);
    _setSelection(next);
  }

  void _setSelection(Map<String, Item> next) {
    final fp = avatarLookFingerprint(
      selected: next,
      pose: state.pose,
      style: state.style,
      quality: state.quality,
    );
    final cached = state.renderCache[fp];
    state = state.copyWith(
      selected: next,
      previewUrl: cached?.previewUrl,
      outfitId: cached?.outfitId,
      clearPreview: cached == null,
      clearError: true,
    );
  }

  /// Drop selections that were soft-deleted from the wardrobe.
  void pruneMissing(Set<String> activeIds) {
    final next = Map<String, Item>.from(state.selected)
      ..removeWhere((_, item) => !activeIds.contains(item.id));
    if (next.length != state.selected.length) {
      _setSelection(next);
    }
  }

  void reset() {
    state = AvatarStudioState(
      activeSlot: state.activeSlot,
      pose: state.pose,
      style: state.style,
      quality: state.quality,
      renderCache: state.renderCache,
      history: state.history,
    );
  }

  void startRender() {
    state = state.copyWith(isRendering: true, clearError: true);
  }

  void completeRender(String previewUrl, {String? outfitId}) {
    final id = outfitId ?? state.outfitId;
    final cache = Map<String, CachedLook>.from(state.renderCache);
    if (id != null) {
      cache[state.currentFingerprint] = CachedLook(
        previewUrl: previewUrl,
        outfitId: id,
      );
    }
    var history = List<AvatarHistoryLook>.from(state.history);
    if (id != null) {
      history.removeWhere((look) => look.outfitId == id);
      history.insert(
        0,
        AvatarHistoryLook(
          outfitId: id,
          previewUrl: previewUrl,
          slots: {
            for (final entry in state.selected.entries) entry.key: entry.value.id,
          },
          pose: state.pose,
          style: state.style,
          quality: state.quality,
          fingerprint: state.currentFingerprint,
        ),
      );
      if (history.length > 24) {
        history = history.take(24).toList();
      }
    }
    state = state.copyWith(
      previewUrl: previewUrl,
      outfitId: id,
      isRendering: false,
      clearError: true,
      renderCache: cache,
      history: history,
    );
  }

  void failRender(String message) {
    state = state.copyWith(isRendering: false, renderError: message);
  }

  void removeHistoryLook(String outfitId) {
    final history =
        state.history.where((look) => look.outfitId != outfitId).toList();
    final cache = Map<String, CachedLook>.from(state.renderCache)
      ..removeWhere((_, look) => look.outfitId == outfitId);
    final clear = state.outfitId == outfitId;
    state = state.copyWith(
      history: history,
      renderCache: cache,
      clearPreview: clear,
      clearOutfitId: clear,
    );
  }

  void setHistory(List<AvatarHistoryLook> looks) {
    final cache = Map<String, CachedLook>.from(state.renderCache);
    for (final look in looks) {
      final fp = [
        'v1',
        'pose=${look.pose}',
        'style=${look.style}',
        'quality=${look.quality}',
        for (final slot in avatarSlots)
          if (look.slots.containsKey(slot.id))
            '${slot.id}=${look.slots[slot.id]}',
      ].join('|');
      cache[fp] = CachedLook(
        previewUrl: look.previewUrl,
        outfitId: look.outfitId,
      );
    }
    state = state.copyWith(history: looks, renderCache: cache);
  }

  /// Restore a previously rendered look (slots + preview) without AI.
  bool restoreHistoryLook(
    AvatarHistoryLook look,
    Map<String, Item> wardrobeById,
  ) {
    final selected = <String, Item>{};
    for (final entry in look.slots.entries) {
      if (!avatarSlots.any((s) => s.id == entry.key)) continue;
      final item = wardrobeById[entry.value];
      if (item == null) return false;
      selected[entry.key] = item;
    }
    if (selected.isEmpty) return false;

    final cache = Map<String, CachedLook>.from(state.renderCache);
    final fp = avatarLookFingerprint(
      selected: selected,
      pose: look.pose,
      style: look.style,
      quality: look.quality,
    );
    cache[fp] = CachedLook(
      previewUrl: look.previewUrl,
      outfitId: look.outfitId,
    );
    state = state.copyWith(
      selected: selected,
      pose: look.pose,
      style: look.style,
      quality: look.quality,
      previewUrl: look.previewUrl,
      outfitId: look.outfitId,
      renderCache: cache,
      clearError: true,
      isRendering: false,
    );
    return true;
  }
}

bool itemFitsAvatarSlot(Item item, String slot) {
  final category = item.category.toLowerCase().replaceAll(' ', '_');
  final subtype = item.subCategory.toLowerCase().replaceAll(' ', '_');
  final text = '$category $subtype';

  const topSubs = {
    'shirt',
    't_shirt',
    'tshirt',
    'polo',
    'kurta',
    'blouse',
    'sweater',
    'hoodie',
    'top',
  };
  const bottomSubs = {
    'trousers',
    'pants',
    'jeans',
    'chinos',
    'shorts',
    'skirt',
    'churidar',
    'dhoti',
    'palazzo',
  };
  const dressSubs = {
    'sherwani',
    'saree',
    'lehenga',
    'anarkali',
    'gown',
    'jumpsuit',
    'dress',
  };
  const outerSubs = {
    'jacket',
    'blazer',
    'coat',
    'nehru_jacket',
    'bandhgala',
    'overcoat',
  };

  switch (slot) {
    case 'tops':
      if ({'bottom', 'bottoms', 'footwear', 'shoe', 'shoes', 'accessory'}
          .contains(category)) {
        return false;
      }
      return category == 'top' ||
          category == 'tops' ||
          (category == 'ethnic' && topSubs.contains(subtype));
    case 'bottoms':
      if ({'top', 'tops', 'footwear', 'shoe', 'shoes', 'accessory'}
          .contains(category)) {
        return false;
      }
      return category == 'bottom' ||
          category == 'bottoms' ||
          (category == 'ethnic' && bottomSubs.contains(subtype)) ||
          (category.isEmpty && bottomSubs.contains(subtype));
    case 'dresses':
      if ({'bottom', 'bottoms', 'footwear', 'shoe', 'shoes'}.contains(category)) {
        return false;
      }
      return category == 'dress' ||
          category == 'dresses' ||
          dressSubs.contains(subtype) ||
          (category == 'ethnic' && dressSubs.contains(subtype));
    case 'outerwear':
      if ({'bottom', 'bottoms', 'footwear', 'shoe', 'shoes'}.contains(category)) {
        return false;
      }
      return category == 'outer' ||
          category == 'outerwear' ||
          outerSubs.contains(subtype) ||
          (category == 'ethnic' && outerSubs.contains(subtype));
    case 'footwear':
      if ({'top', 'tops', 'bottom', 'bottoms', 'dress', 'dresses', 'outerwear'}
          .contains(category)) {
        return false;
      }
      return category == 'shoe' ||
          category == 'shoes' ||
          category == 'footwear' ||
          text.contains('oxford') ||
          text.contains('sneaker') ||
          text.contains('loafer') ||
          text.contains('boot');
    case 'caps':
      return text.contains('cap') ||
          text.contains('hat') ||
          text.contains('beanie');
    case 'glasses':
      return text.contains('glass') ||
          text.contains('sunglass') ||
          text.contains('eyewear');
    case 'accessories':
      final isAccessory = {
        'accessory',
        'accessories',
        'bag',
        'jewelry',
        'jewellery',
      }.contains(category);
      return isAccessory &&
          !itemFitsAvatarSlot(item, 'caps') &&
          !itemFitsAvatarSlot(item, 'glasses');
    default:
      return false;
  }
}
