import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../widgets/try_on_photo_guide_overlay.dart';

/// Pick + upload a full-body try-on reference photo, with optional tips overlay.
/// Returns true when a new photo was saved.
Future<bool> uploadTryOnPhotoInPlace(
  WidgetRef ref,
  BuildContext context, {
  bool forceGuide = false,
  ImageSource source = ImageSource.gallery,
}) async {
  final showGuide = forceGuide || await TryOnPhotoGuideOverlay.shouldShow();
  if (showGuide && context.mounted) {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TryOnPhotoGuideOverlay(
        onContinue: () => Navigator.of(ctx).pop('continue'),
        onCancel: () => Navigator.of(ctx).pop('cancel'),
      ),
    );
    if (result != 'continue' || !context.mounted) return false;
  }

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1200,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return false;

  try {
    await ref.read(apiClientProvider).uploadTryOnPhoto(picked.path);
    ref.invalidate(userProfileProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo saved. Your avatar is being prepared.'),
          backgroundColor: AppColors.lime,
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
    return false;
  }
}

Future<bool> deleteTryOnPhotoInPlace(
    WidgetRef ref, BuildContext context) async {
  try {
    await ref.read(apiClientProvider).deleteTryOnPhoto();
    ref.invalidate(userProfileProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tryon_photo_nudge_dismissed', false);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove photo: $e')),
      );
    }
    return false;
  }
}
