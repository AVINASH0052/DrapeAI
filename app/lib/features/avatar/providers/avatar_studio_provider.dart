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

final avatarWardrobeProvider = FutureProvider<List<Item>>((ref) async {
  final data = await ref.read(apiClientProvider).getItems();
  return (data['items'] as List)
      .map((json) => Item.fromJson(json as Map<String, dynamic>))
      .toList();
});

class AvatarStudioState {
  const AvatarStudioState({
    this.activeSlot = 'tops',
    this.selected = const {},
    this.previewUrl,
    this.isRendering = false,
    this.renderError,
  });

  final String activeSlot;
  final Map<String, Item> selected;
  final String? previewUrl;
  final bool isRendering;
  final String? renderError;

  AvatarStudioState copyWith({
    String? activeSlot,
    Map<String, Item>? selected,
    String? previewUrl,
    bool clearPreview = false,
    bool? isRendering,
    String? renderError,
    bool clearError = false,
  }) {
    return AvatarStudioState(
      activeSlot: activeSlot ?? this.activeSlot,
      selected: selected ?? this.selected,
      previewUrl: clearPreview ? null : (previewUrl ?? this.previewUrl),
      isRendering: isRendering ?? this.isRendering,
      renderError: clearError ? null : (renderError ?? this.renderError),
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
    state = state.copyWith(
      selected: next,
      clearPreview: true,
      clearError: true,
    );
  }

  void clearSlot(String slot) {
    final next = Map<String, Item>.from(state.selected)..remove(slot);
    state = state.copyWith(
      selected: next,
      clearPreview: true,
      clearError: true,
    );
  }

  void reset() {
    state = AvatarStudioState(activeSlot: state.activeSlot);
  }

  void startRender() {
    state = state.copyWith(isRendering: true, clearError: true);
  }

  void completeRender(String previewUrl) {
    state = state.copyWith(
      previewUrl: previewUrl,
      isRendering: false,
      clearError: true,
    );
  }

  void failRender(String message) {
    state = state.copyWith(isRendering: false, renderError: message);
  }
}

bool itemFitsAvatarSlot(Item item, String slot) {
  final category = item.category.toLowerCase().replaceAll(' ', '_');
  final subtype = item.subCategory.toLowerCase().replaceAll(' ', '_');
  final text = '$category $subtype';
  switch (slot) {
    case 'tops':
      return category == 'top' || category == 'tops';
    case 'bottoms':
      return category == 'bottom' || category == 'bottoms';
    case 'dresses':
      return category == 'dress' || category == 'dresses';
    case 'outerwear':
      return category == 'outer' || category == 'outerwear';
    case 'footwear':
      return category == 'shoe' ||
          category == 'shoes' ||
          category == 'footwear';
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
