import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/avatar/presentation/avatar_studio_screen.dart';
import '../../features/avatar/presentation/body_setup_screen.dart';
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
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/legal_screens.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/try_on/presentation/fitting_room_screen.dart';
import '../../features/try_on/presentation/try_on_home_screen.dart';
import '../../features/try_on/presentation/try_on_history_screen.dart';
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
      final needsBody = authStatus == AuthStatus.bodySetupNeeded;
      final isOnLoginPage = state.matchedLocation == '/login';
      final isOnOnboarding = state.matchedLocation == '/onboarding';
      final isOnBodySetup = state.matchedLocation == '/body-setup';

      if (authStatus == AuthStatus.loading ||
          authStatus == AuthStatus.initial) {
        return null;
      }

      if (authStatus == AuthStatus.unauthenticated) {
        return isOnLoginPage ? null : '/login';
      }

      if (isOnboarding) {
        return isOnBodySetup ? null : '/body-setup';
      }

      if (needsBody) {
        return isOnBodySetup ? null : '/body-setup';
      }

      if (isLoggedIn && (isOnLoginPage || isOnOnboarding)) {
        return '/studio';
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
      GoRoute(
        path: '/body-setup',
        name: 'body_setup',
        builder: (_, __) => const BodySetupScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/studio',
            name: 'avatar_studio',
            builder: (_, __) => const AvatarStudioScreen(),
          ),
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
          GoRoute(
            path: '/fitting-room',
            name: 'fitting_room',
            builder: (_, __) => const FittingRoomScreen(),
            routes: [
              GoRoute(
                path: 'shop',
                name: 'fitting_room_shop',
                builder: (_, __) => const TryOnHomeScreen(),
              ),
              GoRoute(
                path: 'history',
                name: 'fitting_room_history',
                builder: (_, __) => const TryOnHistoryScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (_, __) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/analytics',
            name: 'analytics',
            builder: (_, __) => const AnalyticsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (_, state) => CameraScreen(
          returnRoute: state.uri.queryParameters['returnTo'] == 'studio'
              ? '/studio'
              : '/wardrobe',
        ),
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
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (_, __) => const AboutScreen(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (_, __) => const TermsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      // Legacy deep links → Fitting Room shop flow
      GoRoute(
        path: '/try-on',
        redirect: (_, __) => '/fitting-room/shop',
      ),
      GoRoute(
        path: '/try-on/history',
        redirect: (_, __) => '/fitting-room/history',
      ),
    ],
  );
});
