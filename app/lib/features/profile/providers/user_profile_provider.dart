import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Live user profile from GET /me + GET /me/preferences.
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final api = ref.read(apiClientProvider);
  final me = await api.getMe();
  Map<String, dynamic>? prefs;
  try {
    prefs = await api.getPreferences();
  } catch (_) {
    prefs = null;
  }
  return UserProfile.fromApi(me, prefs);
});

class UserProfile {
  final String id;
  final String displayName;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? tryOnPhotoUrl;
  final DateTime? createdAt;
  final List<String> styleTags;
  final String? city;
  final String? gender;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.phone,
    this.photoUrl,
    this.tryOnPhotoUrl,
    this.createdAt,
    this.styleTags = const [],
    this.city,
    this.gender,
  });

  factory UserProfile.fromApi(
    Map<String, dynamic> me,
    Map<String, dynamic>? prefs,
  ) {
    final tags = <String>[];
    if (prefs != null) {
      if (prefs['gender'] != null) tags.add(_cap(prefs['gender'] as String));
      for (final g in (prefs['style_goals'] as List?) ?? []) {
        tags.add(_cap(g.toString()));
      }
      for (final o in (prefs['occasions'] as List?) ?? []) {
        if (tags.length < 8) tags.add(_cap(o.toString()));
      }
      for (final c in (prefs['color_preferences'] as List?) ?? []) {
        if (tags.length < 10) tags.add(_cap(c.toString()));
      }
      if (prefs['fit_preference'] != null) {
        tags.add(_cap(prefs['fit_preference'] as String));
      }
      if (prefs['location_city'] != null) {
        tags.add(prefs['location_city'] as String);
      }
    }

    return UserProfile(
      id: me['id'] as String? ?? '',
      displayName: me['display_name'] as String? ??
          prefs?['name'] as String? ??
          'Stylist',
      email: me['email'] as String?,
      phone: me['phone'] as String?,
      photoUrl: me['photo_url'] as String?,
      tryOnPhotoUrl: me['try_on_photo_url'] as String?,
      createdAt: me['created_at'] != null
          ? DateTime.tryParse(me['created_at'] as String)
          : null,
      styleTags: tags,
      city: prefs?['location_city'] as String?,
      gender: prefs?['gender'] as String?,
    );
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String get memberSince {
    if (createdAt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'member since ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
