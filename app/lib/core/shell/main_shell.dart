import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  int _currentIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/wardrobe')) return 0;
    if (path.startsWith('/today') || path.startsWith('/shuffle')) return 1;
    if (path.startsWith('/lookbooks')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/wardrobe');
            case 1:
              context.go('/today');
            case 2:
              context.go('/lookbooks');
            case 3:
              context.go('/profile');
          }
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.checkroom_outlined, Icons.checkroom, 'Wardrobe'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Outfits'),
    (Icons.collections_bookmark_outlined, Icons.collections_bookmark, 'Lookbooks'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.92),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ColorFilter.mode(
            AppColors.bg.withValues(alpha: 0.1),
            BlendMode.srcOver,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final (icon, activeIcon, label) = _items[i];
                  final isActive = i == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive ? activeIcon : icon,
                            size: 22,
                            color: isActive
                                ? AppColors.orange
                                : AppColors.ink3,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? AppColors.orange
                                  : AppColors.ink3,
                            ),
                          ),
                        ],
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
}
