import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  int _currentIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/wardrobe')) return 0;
    if (path.startsWith('/today') || path.startsWith('/shuffle')) return 1;
    if (path.startsWith('/studio')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: (isDark ? AppColorsDark.card : AppColors.card)
                    .withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? AppColorsDark.border : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(_items.length, (i) {
                  final (icon, activeIcon, label) = _items[i];
                  final isActive = i == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _navigate(context, i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        decoration: isActive
                            ? BoxDecoration(
                                gradient: AppGradients.cta,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.orange
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              )
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? activeIcon : icon,
                              size: isActive ? 20 : 18,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.textMuted(context),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/wardrobe');
      case 1:
        context.go('/today');
      case 2:
        context.go('/studio');
      case 3:
        context.go('/profile');
    }
  }

  static const _items = [
    (Icons.checkroom_outlined, Icons.checkroom, 'Closet'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Fit'),
    (Icons.accessibility_new_outlined, Icons.accessibility_new, 'Studio'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'You'),
  ];
}
