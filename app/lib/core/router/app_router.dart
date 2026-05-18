import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/wardrobe/presentation/wardrobe_screen.dart';
import '../../features/wardrobe/presentation/item_detail_screen.dart';
import '../../features/wardrobe/presentation/camera_screen.dart';
import '../../features/wardrobe/presentation/tag_review_screen.dart';
import '../../features/wardrobe/presentation/gaps_screen.dart';
import '../../features/outfits/presentation/today_screen.dart';
import '../../features/outfits/presentation/shuffle_screen.dart';
import '../../features/lookbooks/presentation/lookbooks_screen.dart';
import '../../features/lookbooks/presentation/lookbook_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<int>(0);
  ref.listen<AuthStatus>(authStatusProvider, (_, __) => notifier.value++);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/login',
    redirect: (context, state) {
      final authStatus = ref.read(authStatusProvider);
      final isLoggedIn = authStatus == AuthStatus.authenticated;
      final isOnboarding = authStatus == AuthStatus.onboardingNeeded;
      final isOnLoginPage = state.matchedLocation == '/login';
      final isOnOnboarding = state.matchedLocation == '/onboarding';

      if (authStatus == AuthStatus.loading ||
          authStatus == AuthStatus.initial) {
        return null;
      }

      if (authStatus == AuthStatus.unauthenticated) {
        return isOnLoginPage ? null : '/login';
      }

      if (isOnboarding) {
        return isOnOnboarding ? null : '/onboarding';
      }

      if (isLoggedIn && (isOnLoginPage || isOnOnboarding)) {
        return '/wardrobe';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/wardrobe',
            name: 'wardrobe',
            builder: (_, __) => const WardrobeScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'item_detail',
                builder: (_, state) =>
                    ItemDetailScreen(itemId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/today',
            name: 'today_outfits',
            builder: (_, __) => const TodayScreen(),
          ),
          GoRoute(
            path: '/shuffle',
            name: 'shuffle',
            builder: (_, __) => const ShuffleScreen(),
          ),
          GoRoute(
            path: '/lookbooks',
            name: 'lookbooks',
            builder: (_, __) => const LookbooksScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'lookbook_detail',
                builder: (_, state) => LookbookDetailScreen(
                  lookbookId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (_, __) => const CameraScreen(),
      ),
      GoRoute(
        path: '/tag-review',
        name: 'tag_review',
        builder: (_, state) => TagReviewScreen(
          itemData: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/wardrobe-gaps',
        name: 'wardrobe_gaps',
        builder: (_, __) => const GapsScreen(),
      ),
    ],
  );
});
