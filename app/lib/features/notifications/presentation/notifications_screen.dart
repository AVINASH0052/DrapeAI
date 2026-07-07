import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/drape_ui.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              DrapeScreenHeader(
                title: 'Notifications',
                subtitle: 'fits, tips & updates',
                gradientTitle: true,
                actions: [
                  TextButton(
                    onPressed: () async {
                      final api = ref.read(apiClientProvider);
                      await api.markAllNotificationsRead();
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                    },
                    child: Text(
                      'Mark all read',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load notifications',
              style: AppTypography.body),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: isDark ? AppColorsDark.ink3 : AppColors.ink3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ll keep you posted on outfit\nsuggestions and wardrobe tips.',
                    style: AppTypography.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif['is_read'] as bool;
              return _NotificationTile(
                title: notif['title'] as String,
                body: notif['body'] as String,
                type: notif['type'] as String,
                isRead: isRead,
                createdAt: notif['created_at'] as String,
                onTap: () async {
                  if (!isRead) {
                    final api = ref.read(apiClientProvider);
                    await api.markNotificationRead(notif['id'] as String);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadCountProvider);
                  }
                },
              );
            },
          );
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

class _NotificationTile extends StatelessWidget {
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String createdAt;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    return switch (type) {
      'outfit' => Icons.checkroom_rounded,
      'wardrobe' => Icons.grid_view_rounded,
      'system' => Icons.settings_rounded,
      'promo' => Icons.local_offer_rounded,
      _ => Icons.info_outline_rounded,
    };
  }

  Color _colorForType(String type, bool isDark) {
    return switch (type) {
      'outfit' => AppColors.orange,
      'wardrobe' => AppColors.lavender,
      'system' => isDark ? AppColorsDark.ink3 : AppColors.ink3,
      'promo' => AppColors.pink,
      _ => AppColors.orange,
    };
  }

  String _timeAgo(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _colorForType(type, isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColorsDark.card : AppColors.card,
          border: Border.all(
            color: isRead
                ? (isDark ? AppColorsDark.border : AppColors.border)
                : accent.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconForType(type), color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.label.copyWith(
                            fontWeight:
                                isRead ? FontWeight.w400 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeAgo(createdAt),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: AppTypography.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
