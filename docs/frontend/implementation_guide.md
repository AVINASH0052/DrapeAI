# Sugatai Frontend -- Implementation Guide (historical)

> **Stale scaffold.** Do not follow this to create a new app. Live product is **Sugatai** (`com.sugatai.sugatai`). Canonical: [../services/FRONTEND.md](../services/FRONTEND.md).

Step-by-step instructions: what to build, screen by screen, widget by widget, with code.

---

## Phase 1 -- Project Scaffold

### What you're building
Flutter project skeleton with theme, routing shell, and bottom navigation.

### Step 1.1 -- Create Flutter project

```bash
flutter create --org com.drapeai --project-name drapeai app
cd app
```

### Step 1.2 -- `pubspec.yaml` dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Navigation
  go_router: ^14.0.0

  # Network
  dio: ^5.5.0

  # Firebase
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.0
  firebase_messaging: ^15.0.0
  google_sign_in: ^6.2.0

  # UI
  google_fonts: ^6.2.0
  cached_network_image: ^3.4.0
  flutter_svg: ^2.0.0
  shimmer: ^3.0.0

  # Camera
  camera: ^0.11.0
  image_picker: ^1.1.0
  image: ^4.2.0

  # Storage
  shared_preferences: ^2.3.0
  path_provider: ^2.1.0

  # Utils
  intl: ^0.19.0
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
  mockito: ^5.4.0
```

### Step 1.3 -- `lib/core/theme/app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.gray900,
      secondary: AppColors.indigo500,
      surface: Colors.white,
      error: AppColors.red500,
    ),
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.interTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.gray900,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gray900,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gray900,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.gray200),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.indigo500, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.gray900,
      unselectedItemColor: AppColors.gray400,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.gray200,
      thickness: 1,
    ),
  );
}
```

### Step 1.4 -- `lib/core/theme/app_colors.dart`

```dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const gray900 = Color(0xFF111827);
  static const gray700 = Color(0xFF374151);
  static const gray500 = Color(0xFF6B7280);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray50 = Color(0xFFF9FAFB);

  // Accent
  static const indigo500 = Color(0xFF6366F1);
  static const indigo50 = Color(0xFFEEF2FF);

  // Semantic
  static const red500 = Color(0xFFEF4444);
  static const red50 = Color(0xFFFEF2F2);
  static const green500 = Color(0xFF22C55E);
  static const green50 = Color(0xFFF0FDF4);
  static const amber500 = Color(0xFFF59E0B);
  static const amber50 = Color(0xFFFFFBEB);
}
```

### Step 1.5 -- `lib/core/theme/app_typography.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.gray900,
  );
  static TextStyle get heading => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.gray900,
  );
  static TextStyle get title => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray900,
  );
  static TextStyle get body => GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.gray700,
  );
  static TextStyle get label => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.gray700,
  );
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.gray500,
  );
  static TextStyle get chip => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray700,
  );
}
```

### Step 1.6 -- `lib/core/router/app_router.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/wardrobe/presentation/wardrobe_screen.dart';
import '../../features/outfits/presentation/today_screen.dart';
import '../../features/outfits/presentation/shuffle_screen.dart';
import '../../features/lookbooks/presentation/lookbooks_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/wardrobe/presentation/item_detail_screen.dart';
import '../../features/wardrobe/presentation/camera_screen.dart';
import '../../features/wardrobe/presentation/tag_review_screen.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/wardrobe',
    routes: [
      // Auth
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

      // Main shell with bottom nav
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
                builder: (_, state) => ItemDetailScreen(
                  itemId: state.pathParameters['id']!,
                ),
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
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Camera flow (outside shell -- no bottom nav)
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
    ],
  );
});
```

### Step 1.7 -- `lib/core/shell/main_shell.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/wardrobe')) return 0;
    if (location.startsWith('/today')) return 1;
    if (location.startsWith('/shuffle')) return 2;
    if (location.startsWith('/lookbooks')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.gray200)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex(context),
          onTap: (i) {
            switch (i) {
              case 0: context.go('/wardrobe');
              case 1: context.go('/today');
              case 2: context.go('/shuffle');
              case 3: context.go('/lookbooks');
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom_outlined),
              activeIcon: Icon(Icons.checkroom),
              label: 'Wardrobe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.wb_sunny_outlined),
              activeIcon: Icon(Icons.wb_sunny),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shuffle_outlined),
              activeIcon: Icon(Icons.shuffle),
              label: 'Shuffle',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.collections_bookmark_outlined),
              activeIcon: Icon(Icons.collections_bookmark),
              label: 'Lookbooks',
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 1.8 -- `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const ProviderScope(child: DrapeAIApp()));
}

class DrapeAIApp extends ConsumerWidget {
  const DrapeAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'DrapeAI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
```

---

## Phase 2 -- Authentication Flow

### What you're building
S2-Auth screen: phone OTP + Google sign-in, Firebase Auth integration, auto-redirect based on onboarding status.

### Step 2.1 -- `lib/features/auth/data/auth_repository.dart`

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final Dio _dio;

  AuthRepository(this._auth, this._googleSignIn, this._dio);

  /// Current Firebase user (null if logged out)
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get current JWT for API calls
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Phone OTP: Step 1 -- send verification code
  Future<String> sendOtp(String phoneNumber) async {
    String verificationId = '';
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (e) {
        throw Exception(e.message ?? 'Phone verification failed');
      },
      codeSent: (id, _) {
        verificationId = id;
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    // Wait briefly for codeSent callback
    await Future.delayed(const Duration(seconds: 1));
    return verificationId;
  }

  /// Phone OTP: Step 2 -- verify code
  Future<User> verifyOtp(String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// Google sign-in
  Future<User> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  /// Verify token with backend (also auto-provisions user)
  Future<Map<String, dynamic>> verifyWithBackend() async {
    final response = await _dio.post('/auth/verify');
    return response.data;
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
```

### Step 2.2 -- `lib/features/auth/providers/auth_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/dio_provider.dart';
import '../data/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, onboardingNeeded }

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    GoogleSignIn(),
    ref.watch(dioProvider),
  );
});

final authStatusProvider = StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  return AuthStatusNotifier(ref);
});

class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  final Ref _ref;

  AuthStatusNotifier(this._ref) : super(AuthStatus.initial) {
    _init();
  }

  Future<void> _init() async {
    final repo = _ref.read(authRepositoryProvider);
    if (repo.currentUser == null) {
      state = AuthStatus.unauthenticated;
      return;
    }
    await _checkBackend();
  }

  Future<void> _checkBackend() async {
    state = AuthStatus.loading;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final data = await repo.verifyWithBackend();
      if (data['onboarding_done'] == true) {
        state = AuthStatus.authenticated;
      } else {
        state = AuthStatus.onboardingNeeded;
      }
    } catch (_) {
      state = AuthStatus.unauthenticated;
    }
  }

  Future<void> onLoginSuccess() async {
    await _checkBackend();
  }

  void logout() {
    _ref.read(authRepositoryProvider).signOut();
    state = AuthStatus.unauthenticated;
  }
}
```

### Step 2.3 -- `lib/features/auth/presentation/auth_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final phone = '+91${_phoneController.text.trim()}';
      _verificationId = await repo.sendOtp(phone);
      setState(() => _otpSent = true);
    } catch (e) {
      _showError('Failed to send OTP: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyOtp(_verificationId!, _otpController.text.trim());
      await ref.read(authStatusProvider.notifier).onLoginSuccess();
      if (mounted) {
        final status = ref.read(authStatusProvider);
        if (status == AuthStatus.onboardingNeeded) {
          context.go('/onboarding');
        } else {
          context.go('/wardrobe');
        }
      }
    } catch (e) {
      _showError('Invalid OTP');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithGoogle();
      await ref.read(authStatusProvider.notifier).onLoginSuccess();
      if (mounted) {
        final status = ref.read(authStatusProvider);
        if (status == AuthStatus.onboardingNeeded) {
          context.go('/onboarding');
        } else {
          context.go('/wardrobe');
        }
      }
    } catch (e) {
      _showError('Google sign-in failed');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              Text('DrapeAI', style: AppTypography.display),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered personal stylist',
                style: AppTypography.body.copyWith(color: AppColors.gray500),
              ),
              const SizedBox(height: 48),

              // Phone input
              if (!_otpSent) ...[
                Text('Phone number', style: AppTypography.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        border: Border.all(color: AppColors.gray200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('+91', style: AppTypography.body),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          hintText: '10-digit mobile number',
                          counterText: '',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send OTP'),
                ),
              ],

              // OTP input
              if (_otpSent) ...[
                Text('Enter OTP', style: AppTypography.label),
                const SizedBox(height: 8),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '6-digit code',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify'),
                ),
                TextButton(
                  onPressed: () => setState(() => _otpSent = false),
                  child: const Text('Change number'),
                ),
              ],

              const SizedBox(height: 24),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or'),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 24),

              // Google sign-in
              OutlinedButton.icon(
                onPressed: _loading ? null : _googleSignIn,
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Continue with Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Phase 3 -- API Client Layer

### What you're building
Shared Dio instance with Firebase JWT interceptor and base URL config.

### Step 3.1 -- `lib/core/constants/environment.dart`

```dart
class Environment {
  Environment._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
```

### Step 3.2 -- `lib/core/network/dio_provider.dart`

```dart
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/environment.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: Environment.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      // Log API errors for debugging
      // ignore: avoid_print
      print('API Error: ${error.requestOptions.path} -> ${error.response?.statusCode}');
      handler.next(error);
    },
  ));

  return dio;
});
```

### Step 3.3 -- `lib/core/network/api_client.dart`

```dart
import 'package:dio/dio.dart';

/// Typed API client wrapping Dio. One method per endpoint.
class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  // --- Auth ---
  Future<Map<String, dynamic>> verifyAuth() async {
    final resp = await _dio.post('/auth/verify');
    return resp.data;
  }

  // --- Preferences ---
  Future<void> savePreferences(Map<String, dynamic> prefs) async {
    await _dio.put('/me/preferences', data: prefs);
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final resp = await _dio.get('/me/preferences');
    return resp.data;
  }

  // --- Items ---
  Future<Map<String, dynamic>> uploadItem(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final resp = await _dio.post('/items/upload', data: formData);
    return resp.data;
  }

  Future<Map<String, dynamic>> getItems({
    String? category,
    String? color,
    String? search,
    String sort = 'newest',
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _dio.get('/items', queryParameters: {
      if (category != null) 'category': category,
      if (color != null) 'color': color,
      if (search != null) 'search': search,
      'sort': sort,
      'limit': limit,
      'offset': offset,
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> getItem(String id) async {
    final resp = await _dio.get('/items/$id');
    return resp.data;
  }

  Future<void> updateItem(String id, Map<String, dynamic> updates) async {
    await _dio.patch('/items/$id', data: updates);
  }

  Future<void> deleteItem(String id) async {
    await _dio.delete('/items/$id');
  }

  // --- Outfits ---
  Future<Map<String, dynamic>> generateOutfits(String occasion) async {
    final resp = await _dio.post('/outfits/generate', data: {'occasion': occasion});
    return resp.data;
  }

  Future<Map<String, dynamic>> shuffleOutfit(String occasion) async {
    final resp = await _dio.post('/outfits/shuffle', data: {'occasion': occasion});
    return resp.data;
  }

  Future<void> submitFeedback(String outfitId, String action) async {
    await _dio.post('/outfits/$outfitId/feedback', data: {'action': action});
  }

  Future<Map<String, dynamic>> getTodayOutfits() async {
    final resp = await _dio.get('/outfits/today');
    return resp.data;
  }

  // --- Lookbooks ---
  Future<Map<String, dynamic>> getLookbooks() async {
    final resp = await _dio.get('/lookbooks');
    return resp.data;
  }

  Future<Map<String, dynamic>> createLookbook(String name) async {
    final resp = await _dio.post('/lookbooks', data: {'name': name});
    return resp.data;
  }

  Future<Map<String, dynamic>> getLookbook(String id) async {
    final resp = await _dio.get('/lookbooks/$id');
    return resp.data;
  }

  Future<void> saveOutfitToLookbook(String lookbookId, String outfitId) async {
    await _dio.post('/lookbooks/$lookbookId/outfits/$outfitId');
  }

  Future<void> deleteLookbook(String id) async {
    await _dio.delete('/lookbooks/$id');
  }

  // --- Push ---
  Future<void> registerPushToken(String token, String platform) async {
    await _dio.post('/push/register', data: {'token': token, 'platform': platform});
  }
}

// Provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dio_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
```

---

## Phase 4 -- Onboarding Quiz

### What you're building
S3-Onboarding: 5-question quiz with visual tile selection. Questions: gender, age, style goals, color preferences, city.

### Step 4.1 -- `lib/features/onboarding/presentation/onboarding_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../widgets/quiz_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentStep = 0;
  bool _saving = false;

  // Quiz answers
  String? _gender;
  String? _ageRange;
  List<String> _styleGoals = [];
  List<String> _colorPrefs = [];
  String _city = '';

  final _steps = const [
    'Gender', 'Age Range', 'Style Goals', 'Color Palette', 'Your City'
  ];

  void _next() {
    if (_currentStep < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.savePreferences({
        'gender': _gender,
        'age_range': _ageRange,
        'style_goals': _styleGoals,
        'color_preferences': _colorPrefs,
        'location_city': _city,
      });
      if (mounted) context.go('/wardrobe');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.red500),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: return _gender != null;
      case 1: return _ageRange != null;
      case 2: return _styleGoals.isNotEmpty;
      case 3: return _colorPrefs.isNotEmpty;
      case 4: return _city.isNotEmpty;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Progress bar
              LinearProgressIndicator(
                value: (_currentStep + 1) / _steps.length,
                backgroundColor: AppColors.gray100,
                color: AppColors.indigo500,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentStep + 1} of ${_steps.length}',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 24),

              // Quiz pages
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Q1: Gender
                    QuizStep(
                      question: 'How do you identify?',
                      options: const ['Male', 'Female', 'Non-binary'],
                      values: const ['male', 'female', 'non_binary'],
                      selected: _gender != null ? [_gender!] : [],
                      multiSelect: false,
                      onChanged: (v) => setState(() => _gender = v.first),
                    ),
                    // Q2: Age
                    QuizStep(
                      question: 'What is your age range?',
                      options: const ['18-24', '25-34', '35-44', '45+'],
                      values: const ['18-24', '25-34', '35-44', '45+'],
                      selected: _ageRange != null ? [_ageRange!] : [],
                      multiSelect: false,
                      onChanged: (v) => setState(() => _ageRange = v.first),
                    ),
                    // Q3: Style goals (multi-select, max 3)
                    QuizStep(
                      question: 'What are your style goals?',
                      subtitle: 'Pick up to 3',
                      options: const [
                        'Casual Upgrade', 'Work Ready', 'Ethnic Modern',
                        'Minimal', 'Streetwear', 'Classic'
                      ],
                      values: const [
                        'casual_upgrade', 'work_ready', 'ethnic_modern',
                        'minimal', 'streetwear', 'classic'
                      ],
                      selected: _styleGoals,
                      multiSelect: true,
                      maxSelections: 3,
                      onChanged: (v) => setState(() => _styleGoals = v),
                    ),
                    // Q4: Color preferences (multi-select)
                    QuizStep(
                      question: 'Which color palettes do you prefer?',
                      options: const [
                        'Earth Tones', 'Pastels', 'Bold & Bright',
                        'Monochrome', 'Jewel Tones', 'Neutrals'
                      ],
                      values: const [
                        'earth', 'pastels', 'bold',
                        'monochrome', 'jewel', 'neutrals'
                      ],
                      selected: _colorPrefs,
                      multiSelect: true,
                      onChanged: (v) => setState(() => _colorPrefs = v),
                    ),
                    // Q5: City
                    _buildCityStep(),
                  ],
                ),
              ),

              // Next button
              ElevatedButton(
                onPressed: _canProceed && !_saving ? _next : null,
                child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_currentStep == _steps.length - 1 ? 'Get Started' : 'Next'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which city are you in?', style: AppTypography.heading),
        const SizedBox(height: 8),
        Text('We use this for weather-based outfit suggestions', style: AppTypography.body.copyWith(color: AppColors.gray500)),
        const SizedBox(height: 24),
        TextField(
          onChanged: (v) => setState(() => _city = v),
          decoration: const InputDecoration(hintText: 'e.g. Mumbai, Delhi, Bangalore'),
        ),
      ],
    );
  }
}
```

### Step 4.2 -- `lib/features/onboarding/widgets/quiz_step.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class QuizStep extends StatelessWidget {
  final String question;
  final String? subtitle;
  final List<String> options;
  final List<String> values;
  final List<String> selected;
  final bool multiSelect;
  final int? maxSelections;
  final ValueChanged<List<String>> onChanged;

  const QuizStep({
    required this.question,
    this.subtitle,
    required this.options,
    required this.values,
    required this.selected,
    required this.multiSelect,
    this.maxSelections,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: AppTypography.heading),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTypography.body.copyWith(color: AppColors.gray500)),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(options.length, (i) {
            final isSelected = selected.contains(values[i]);
            return GestureDetector(
              onTap: () {
                if (multiSelect) {
                  final newList = List<String>.from(selected);
                  if (isSelected) {
                    newList.remove(values[i]);
                  } else if (maxSelections == null || newList.length < maxSelections!) {
                    newList.add(values[i]);
                  }
                  onChanged(newList);
                } else {
                  onChanged([values[i]]);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.indigo50 : Colors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.indigo500 : AppColors.gray200,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  options[i],
                  style: AppTypography.label.copyWith(
                    color: isSelected ? AppColors.indigo500 : AppColors.gray700,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
```

---

## Phase 5 -- Camera + Upload Flow

### What you're building
S5-Camera screen with overlay guide, rotating tips, quality checks, and multi-source upload (camera, gallery).

### Step 5.1 -- `lib/features/wardrobe/presentation/camera_screen.dart`

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _error;

  final _tips = const [
    'Lay item flat on a plain surface',
    'Use natural lighting for best results',
    'Capture the full garment in frame',
    'Avoid shadows and wrinkles',
  ];
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    // Rotate tips every 3 seconds
    _rotateTips();
  }

  void _rotateTips() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
        _rotateTips();
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (file == null) return;
      await _upload(file.path);
    } catch (e) {
      setState(() => _error = 'Failed to pick image');
    }
  }

  Future<void> _upload(String path) async {
    setState(() { _uploading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.uploadItem(path);
      if (mounted) {
        context.pushNamed('tag_review', extra: result);
      }
    } catch (e) {
      setState(() => _error = 'Upload failed. Please try again.');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Item'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Overlay frame area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  border: Border.all(color: AppColors.gray200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _uploading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.indigo500),
                          const SizedBox(height: 16),
                          Text('Processing your item...', style: AppTypography.body),
                          const SizedBox(height: 4),
                          Text('Removing background and tagging', style: AppTypography.caption),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.checkroom_outlined, size: 64, color: AppColors.gray400),
                          const SizedBox(height: 16),
                          Text('Take a photo or choose from gallery', style: AppTypography.body),
                        ],
                      ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Rotating tip
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_tipIndex),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20, color: AppColors.amber500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_tips[_tipIndex], style: AppTypography.caption),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTypography.caption.copyWith(color: AppColors.red500)),
            ],

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 6 -- Auto-Tag Review

### What you're building
S6: After upload, show AI-generated tags as chips. User can tap to edit any tag before confirming.

### Step 6.1 -- `lib/features/wardrobe/presentation/tag_review_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

class TagReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> itemData;
  const TagReviewScreen({required this.itemData, super.key});

  @override
  ConsumerState<TagReviewScreen> createState() => _TagReviewScreenState();
}

class _TagReviewScreenState extends ConsumerState<TagReviewScreen> {
  late Map<String, dynamic> _tags;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tags = Map<String, dynamic>.from(widget.itemData['tags'] ?? {});
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.updateItem(widget.itemData['id'], _tags);
      if (mounted) context.go('/wardrobe');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.red500),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  void _editTag(String key, String currentValue, List<String> options) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select $key', style: AppTypography.title),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) {
                final isSelected = opt == currentValue;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  selectedColor: AppColors.indigo50,
                  onSelected: (_) {
                    setState(() => _tags[key] = opt);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confidence = ((_tags['confidence'] ?? 0.0) * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Tags'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Item image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.itemData['image_url'] ?? '',
                height: 300,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (_, __) => Container(
                  height: 300, color: AppColors.gray100,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Confidence
            Row(
              children: [
                Text('AI Confidence: $confidence%', style: AppTypography.label),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_tags['confidence'] ?? 0.0).toDouble(),
                    backgroundColor: AppColors.gray100,
                    color: confidence > 80 ? AppColors.green500 : AppColors.amber500,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              'Tap any tag to correct it',
              style: AppTypography.caption,
            ),

            const SizedBox(height: 24),

            // Tag rows
            _tagRow('Category', _tags['category'] ?? '', ['top', 'bottom', 'footwear', 'accessory', 'outerwear', 'ethnic']),
            _tagRow('Sub-category', _tags['sub_category'] ?? '', []),
            _tagRow('Color', _tags['primary_color'] ?? '', ['navy', 'black', 'white', 'grey', 'beige', 'brown', 'maroon', 'olive', 'blue', 'red', 'cream', 'green', 'pink', 'yellow']),
            _tagRow('Pattern', _tags['pattern'] ?? '', ['solid', 'striped', 'checked', 'printed', 'floral', 'geometric', 'embroidered', 'abstract']),
            _tagRow('Fabric', _tags['fabric'] ?? '', ['cotton', 'silk', 'polyester', 'denim', 'linen', 'wool', 'chiffon', 'georgette', 'synthetic', 'leather']),
            _tagRow('Formality', '${_tags['formality'] ?? 3}', ['1', '2', '3', '4', '5']),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saving ? null : _confirm,
              child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Confirm and Add to Wardrobe'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _tagRow(String label, String value, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: GestureDetector(
              onTap: options.isNotEmpty ? () => _editTag(label.toLowerCase(), value, options) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  border: Border.all(color: AppColors.gray200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: AppTypography.label),
                    if (options.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.gray400),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 7 -- Wardrobe Grid

### What you're building
S7: 3-column grid of all items, filter row (category chips), search bar, FAB with camera/gallery options.

### Step 7.1 -- `lib/features/wardrobe/domain/item_model.dart`

```dart
class Item {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String category;
  final String subCategory;
  final String primaryColor;
  final List<String> secondaryColors;
  final String pattern;
  final String fabric;
  final List<String> styleTags;
  final int formality;
  final List<String> seasonTags;
  final bool ethnicFlag;
  final int wearCount;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    required this.subCategory,
    required this.primaryColor,
    this.secondaryColors = const [],
    this.pattern = 'solid',
    this.fabric = 'cotton',
    this.styleTags = const [],
    this.formality = 3,
    this.seasonTags = const ['all_season'],
    this.ethnicFlag = false,
    this.wearCount = 0,
    required this.createdAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      imageUrl: json['image_url'],
      thumbnailUrl: json['thumbnail_url'],
      category: json['category'],
      subCategory: json['sub_category'],
      primaryColor: json['primary_color'],
      secondaryColors: List<String>.from(json['secondary_colors'] ?? []),
      pattern: json['pattern'] ?? 'solid',
      fabric: json['fabric'] ?? 'cotton',
      styleTags: List<String>.from(json['style_tags'] ?? []),
      formality: json['formality'] ?? 3,
      seasonTags: List<String>.from(json['season_tags'] ?? ['all_season']),
      ethnicFlag: json['ethnic_flag'] ?? false,
      wearCount: json['wear_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
```

### Step 7.2 -- `lib/features/wardrobe/providers/wardrobe_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/item_model.dart';

final wardrobeCategoryFilter = StateProvider<String?>((ref) => null);
final wardrobeSearchQuery = StateProvider<String>((ref) => '');

final wardrobeProvider = AsyncNotifierProvider<WardrobeNotifier, List<Item>>(
  WardrobeNotifier.new,
);

class WardrobeNotifier extends AsyncNotifier<List<Item>> {
  @override
  Future<List<Item>> build() async {
    final category = ref.watch(wardrobeCategoryFilter);
    final search = ref.watch(wardrobeSearchQuery);

    final api = ref.read(apiClientProvider);
    final data = await api.getItems(
      category: category,
      search: search.isNotEmpty ? search : null,
    );
    final items = (data['items'] as List).map((j) => Item.fromJson(j)).toList();
    return items;
  }

  Future<void> deleteItem(String id) async {
    final api = ref.read(apiClientProvider);
    await api.deleteItem(id);
    state = AsyncValue.data(
      state.value?.where((i) => i.id != id).toList() ?? [],
    );
  }

  void refresh() => ref.invalidateSelf();
}
```

### Step 7.3 -- `lib/features/wardrobe/presentation/wardrobe_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/wardrobe_provider.dart';
import '../widgets/item_card.dart';

class WardrobeScreen extends ConsumerWidget {
  const WardrobeScreen({super.key});

  static const _categories = [null, 'top', 'bottom', 'footwear', 'ethnic', 'outerwear', 'accessory'];
  static const _categoryLabels = ['All', 'Tops', 'Bottoms', 'Footwear', 'Ethnic', 'Outerwear', 'Accessories'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wardrobeProvider);
    final activeCategory = ref.watch(wardrobeCategoryFilter);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Wardrobe', style: AppTypography.heading),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isActive = activeCategory == _categories[i];
                return ChoiceChip(
                  label: Text(_categoryLabels[i]),
                  selected: isActive,
                  selectedColor: AppColors.gray900,
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : AppColors.gray700,
                  ),
                  onSelected: (_) {
                    ref.read(wardrobeCategoryFilter.notifier).state = _categories[i];
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Items grid
          Expanded(
            child: items.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load wardrobe', style: AppTypography.body),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(wardrobeProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (itemList) => itemList.isEmpty
                ? _buildEmpty(context)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(wardrobeProvider),
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: itemList.length,
                      itemBuilder: (_, i) => ItemCard(
                        item: itemList[i],
                        onTap: () => context.pushNamed(
                          'item_detail',
                          pathParameters: {'id': itemList[i].id},
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gray900,
        onPressed: () => context.pushNamed('camera'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.checkroom_outlined, size: 64, color: AppColors.gray400),
            const SizedBox(height: 16),
            Text('Your wardrobe is empty', style: AppTypography.title),
            const SizedBox(height: 8),
            Text(
              'Add your first clothing item to get AI-powered outfit recommendations.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.gray500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.pushNamed('camera'),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Add First Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _WardrobeSearchDelegate(ref),
    );
  }
}

class _WardrobeSearchDelegate extends SearchDelegate<String> {
  final WidgetRef _ref;
  _WardrobeSearchDelegate(this._ref);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () { query = ''; }),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) {
    _ref.read(wardrobeSearchQuery.notifier).state = query;
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) => const SizedBox.shrink();
}
```

### Step 7.4 -- `lib/features/wardrobe/widgets/item_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/item_model.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const ItemCard({required this.item, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.gray200),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: item.thumbnailUrl ?? item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.gray100),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.gray100,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.gray400),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                item.subCategory.replaceAll('_', ' '),
                style: AppTypography.chip,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 8 -- Item Detail

### What you're building
S8: Full item view with large image, all tags displayed, edit button, delete button, wear count.

### Step 8.1 -- `lib/features/wardrobe/presentation/item_detail_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../providers/wardrobe_provider.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const ItemDetailScreen({required this.itemId, super.key});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  Map<String, dynamic>? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getItem(widget.itemId);
      setState(() { _item = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This item will be removed from your wardrobe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.red500)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(wardrobeProvider.notifier).deleteItem(widget.itemId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Item not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text((_item!['sub_category'] ?? '').toString().replaceAll('_', ' ')),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _item!['image_url'],
                height: 400,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            _infoRow('Category', _item!['category']),
            _infoRow('Color', _item!['primary_color']),
            _infoRow('Pattern', _item!['pattern']),
            _infoRow('Fabric', _item!['fabric']),
            _infoRow('Formality', '${_item!['formality']}/5'),
            _infoRow('Worn', '${_item!['wear_count'] ?? 0} times'),
            if (_item!['ethnic_flag'] == true)
              _infoRow('Type', 'Indian Ethnic'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: AppTypography.caption)),
          Expanded(child: Text(value, style: AppTypography.label)),
        ],
      ),
    );
  }
}
```

---

## Phase 9 -- Today's Outfits

### What you're building
S9: Generate 3 AI outfits for an occasion. Weather badge, outfit cards with item images, reason text, like/dislike/wear actions.

### Step 9.1 -- `lib/features/outfits/domain/outfit_model.dart`

```dart
import '../../wardrobe/domain/item_model.dart';

class Outfit {
  final String id;
  final List<Item> items;
  final String? reason;
  final double ruleScore;
  final String occasion;
  final Map<String, dynamic>? weather;

  Outfit({
    required this.id,
    required this.items,
    this.reason,
    this.ruleScore = 0,
    required this.occasion,
    this.weather,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'],
      items: (json['items'] as List).map((j) => Item.fromJson(j)).toList(),
      reason: json['reason'],
      ruleScore: (json['rule_score'] ?? 0).toDouble(),
      occasion: json['occasion'] ?? 'casual',
      weather: json['weather'],
    );
  }
}
```

### Step 9.2 -- `lib/features/outfits/providers/today_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/outfit_model.dart';

final selectedOccasionProvider = StateProvider<String>((ref) => 'casual');

final todayOutfitsProvider = FutureProvider<List<Outfit>>((ref) async {
  final api = ref.read(apiClientProvider);
  final data = await api.getTodayOutfits();
  final outfits = (data['outfits'] as List).map((j) => Outfit.fromJson(j)).toList();
  return outfits;
});
```

### Step 9.3 -- `lib/features/outfits/presentation/today_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../providers/today_provider.dart';
import '../domain/outfit_model.dart';
import '../widgets/outfit_card.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _generating = false;

  static const _occasions = ['casual', 'work', 'party', 'date', 'festive', 'gym', 'travel'];

  Future<void> _generate(String occasion) async {
    setState(() => _generating = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.generateOutfits(occasion);
      ref.invalidate(todayOutfitsProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e'), backgroundColor: AppColors.red500),
      );
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfitsAsync = ref.watch(todayOutfitsProvider);
    final occasion = ref.watch(selectedOccasionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Today's Outfits", style: AppTypography.heading),
      ),
      body: Column(
        children: [
          // Occasion chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _occasions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isActive = occasion == _occasions[i];
                return ChoiceChip(
                  label: Text(_occasions[i][0].toUpperCase() + _occasions[i].substring(1)),
                  selected: isActive,
                  selectedColor: AppColors.gray900,
                  labelStyle: TextStyle(color: isActive ? Colors.white : AppColors.gray700),
                  onSelected: (_) {
                    ref.read(selectedOccasionProvider.notifier).state = _occasions[i];
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Generate button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: _generating ? null : () => _generate(occasion),
              child: _generating
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 8),
                      Text('Generating...'),
                    ],
                  )
                : const Text('Generate Outfits'),
            ),
          ),

          const SizedBox(height: 16),

          // Outfit cards
          Expanded(
            child: outfitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load outfits', style: AppTypography.body),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(todayOutfitsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (outfits) => outfits.isEmpty
                ? Center(
                    child: Text(
                      'No outfits yet. Tap Generate to get started.',
                      style: AppTypography.body.copyWith(color: AppColors.gray500),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: outfits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => OutfitCard(outfit: outfits[i]),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Step 9.4 -- `lib/features/outfits/widgets/outfit_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../domain/outfit_model.dart';

class OutfitCard extends ConsumerWidget {
  final Outfit outfit;
  const OutfitCard({required this.outfit, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.indigo500.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item images row
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              itemCount: outfit.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: outfit.items[i].imageUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 96, height: 96, color: AppColors.gray100),
                ),
              ),
            ),
          ),

          // Weather badge
          if (outfit.weather != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${outfit.weather!['temp']}C, ${outfit.weather!['condition']}',
                  style: AppTypography.chip,
                ),
              ),
            ),

          // Reason
          if (outfit.reason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(outfit.reason!, style: AppTypography.body),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _actionButton(Icons.thumb_up_outlined, 'Like', () async {
                  await ref.read(apiClientProvider).submitFeedback(outfit.id, 'like');
                }),
                const SizedBox(width: 8),
                _actionButton(Icons.thumb_down_outlined, 'Dislike', () async {
                  await ref.read(apiClientProvider).submitFeedback(outfit.id, 'dislike');
                }),
                const SizedBox(width: 8),
                _actionButton(Icons.checkroom, 'Wear', () async {
                  await ref.read(apiClientProvider).submitFeedback(outfit.id, 'wear');
                }),
                const Spacer(),
                _actionButton(Icons.bookmark_outline, 'Save', () async {
                  await ref.read(apiClientProvider).submitFeedback(outfit.id, 'save');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.gray500),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.chip),
          ],
        ),
      ),
    );
  }
}
```

---

## Phase 10 -- Shuffle Screen

### What you're building
S10: Tinder-style swipe deck. Swipe right to save, left to skip. Generates one random outfit at a time.

### Step 10.1 -- `lib/features/outfits/presentation/shuffle_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../domain/outfit_model.dart';

class ShuffleScreen extends ConsumerStatefulWidget {
  const ShuffleScreen({super.key});

  @override
  ConsumerState<ShuffleScreen> createState() => _ShuffleScreenState();
}

class _ShuffleScreenState extends ConsumerState<ShuffleScreen> {
  Outfit? _currentOutfit;
  bool _loading = false;
  String _occasion = 'casual';
  Offset _dragOffset = Offset.zero;

  Future<void> _shuffle() async {
    setState(() { _loading = true; _currentOutfit = null; _dragOffset = Offset.zero; });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.shuffleOutfit(_occasion);
      if (data['outfit'] != null) {
        setState(() => _currentOutfit = Outfit.fromJson(data['outfit']));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shuffle failed: $e'), backgroundColor: AppColors.red500),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onDragEnd() async {
    if (_dragOffset.dx > 100) {
      // Swipe right: save
      if (_currentOutfit != null) {
        await ref.read(apiClientProvider).submitFeedback(_currentOutfit!.id, 'save');
      }
      _shuffle();
    } else if (_dragOffset.dx < -100) {
      // Swipe left: skip
      if (_currentOutfit != null) {
        await ref.read(apiClientProvider).submitFeedback(_currentOutfit!.id, 'skip');
      }
      _shuffle();
    } else {
      setState(() => _dragOffset = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shuffle', style: AppTypography.heading),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Occasion selector
            DropdownButton<String>(
              value: _occasion,
              isExpanded: true,
              items: ['casual', 'work', 'party', 'date', 'festive', 'gym', 'travel']
                .map((o) => DropdownMenuItem(value: o, child: Text(o[0].toUpperCase() + o.substring(1))))
                .toList(),
              onChanged: (v) { if (v != null) setState(() => _occasion = v); },
            ),

            const SizedBox(height: 24),

            // Card area
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.indigo500))
                : _currentOutfit == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shuffle, size: 64, color: AppColors.gray400),
                          const SizedBox(height: 16),
                          Text('Tap shuffle to get a random outfit', style: AppTypography.body),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onPanUpdate: (d) => setState(() => _dragOffset += d.delta),
                      onPanEnd: (_) => _onDragEnd(),
                      child: Transform.translate(
                        offset: _dragOffset,
                        child: Transform.rotate(
                          angle: _dragOffset.dx * 0.001,
                          child: _buildOutfitCard(),
                        ),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Shuffle button
            ElevatedButton.icon(
              onPressed: _loading ? null : _shuffle,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
            const SizedBox(height: 24),

            // Swipe hints
            if (_currentOutfit != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Swipe left to skip', style: AppTypography.caption),
                    Text('Swipe right to save', style: AppTypography.caption),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.gray200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentOutfit!.items.map((item) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Score: ${_currentOutfit!.ruleScore.round()}/100',
            style: AppTypography.label,
          ),
        ],
      ),
    );
  }
}
```

---

## Phase 11 -- Lookbooks

### What you're building
S11: 2-column grid of lookbook covers, create new lookbook, view outfits in a lookbook.

### Step 11.1 -- `lib/features/lookbooks/presentation/lookbooks_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

class LookbooksScreen extends ConsumerStatefulWidget {
  const LookbooksScreen({super.key});

  @override
  ConsumerState<LookbooksScreen> createState() => _LookbooksScreenState();
}

class _LookbooksScreenState extends ConsumerState<LookbooksScreen> {
  List<Map<String, dynamic>> _lookbooks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.getLookbooks();
      setState(() => _lookbooks = List<Map<String, dynamic>>.from(data['lookbooks']));
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _createLookbook() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New Lookbook'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Lookbook name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(apiClientProvider).createLookbook(name);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lookbooks', style: AppTypography.heading),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createLookbook),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _lookbooks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.collections_bookmark_outlined, size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  Text('No lookbooks yet', style: AppTypography.title),
                  const SizedBox(height: 8),
                  Text('Save outfits to collections', style: AppTypography.body.copyWith(color: AppColors.gray500)),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: _createLookbook, child: const Text('Create Lookbook')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: _lookbooks.length,
                itemBuilder: (_, i) {
                  final lb = _lookbooks[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.gray200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Center(
                              child: Text(
                                '${lb['outfit_count'] ?? 0}',
                                style: AppTypography.display.copyWith(color: AppColors.gray400),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lb['name'] ?? '', style: AppTypography.label, maxLines: 1),
                              Text('${lb['outfit_count'] ?? 0} outfits', style: AppTypography.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
```

---

## Phase 12 -- Profile + Settings

### What you're building
S12: User profile display, edit preferences, sign out, app info.

### Step 12.1 -- `lib/features/profile/presentation/profile_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.heading),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 24),

          // Profile header
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.gray100,
            child: Icon(Icons.person_outline, size: 40, color: AppColors.gray400),
          ),
          const SizedBox(height: 16),

          // Settings list
          _settingsTile(
            icon: Icons.tune,
            title: 'Style Preferences',
            subtitle: 'Update your style quiz answers',
            onTap: () => context.push('/onboarding'),
          ),
          _settingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Daily outfit reminders',
            onTap: () {},
          ),
          _settingsTile(
            icon: Icons.info_outline,
            title: 'About DrapeAI',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
          const SizedBox(height: 32),

          // Sign out
          OutlinedButton(
            onPressed: () {
              ref.read(authStatusProvider.notifier).logout();
              context.go('/login');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red500,
              side: const BorderSide(color: AppColors.red500),
            ),
            child: const Text('Sign Out'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.gray500),
      title: Text(title, style: AppTypography.label),
      subtitle: Text(subtitle, style: AppTypography.caption),
      trailing: const Icon(Icons.chevron_right, color: AppColors.gray400),
      onTap: onTap,
    );
  }
}
```

---

## Phase 13 -- Polish

### What you're building
Animations, transitions, and final UX details.

### 13.1 -- Page transitions

```dart
// In GoRouter route definitions, add custom transitions:
GoRoute(
  path: '/wardrobe/:id',
  pageBuilder: (context, state) => CustomTransitionPage(
    child: ItemDetailScreen(itemId: state.pathParameters['id']!),
    transitionsBuilder: (_, animation, __, child) =>
      FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 200),
  ),
),
```

### 13.2 -- Outfit card entrance animation

```dart
// Use AnimatedList or staggered animation for outfit cards:
class StaggeredOutfitList extends StatelessWidget {
  final List<Outfit> outfits;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: outfits.length,
      itemBuilder: (_, i) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 300 + (i * 100)),
        builder: (_, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        ),
        child: OutfitCard(outfit: outfits[i]),
      ),
    );
  }
}
```

### 13.3 -- Loading shimmer for all async screens

Use the `shimmer` package:

```dart
Shimmer.fromColors(
  baseColor: AppColors.gray100,
  highlightColor: Colors.white,
  child: Container(
    height: 120,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
  ),
)
```

### 13.4 -- Pull to refresh on all list screens

Already shown in wardrobe screen. Apply same pattern to Today, Lookbooks.

### 13.5 -- Push notification handling

```dart
// In main.dart, after Firebase.initializeApp():
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Show in-app notification banner
});

FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  final screen = message.data['screen'];
  if (screen == 'today_outfits') {
    router.go('/today');
  }
});
```

---

## Checklist

Before submitting to stores, verify:

- [ ] Auth flow: phone OTP login works end-to-end
- [ ] Auth flow: Google sign-in works
- [ ] Onboarding quiz saves preferences and redirects to wardrobe
- [ ] Camera capture + gallery pick + upload works
- [ ] AI tags display correctly on review screen
- [ ] Tag editing works (tap chip -> select new value)
- [ ] Wardrobe grid loads items with filters
- [ ] Item detail shows all info
- [ ] Item delete works (with confirmation dialog)
- [ ] Outfit generation returns 3 cards with reasons
- [ ] Outfit feedback (like/dislike/wear/save) works
- [ ] Shuffle generates random outfits
- [ ] Swipe gestures work on shuffle cards
- [ ] Lookbook creation, listing, and deletion work
- [ ] Profile screen shows user info
- [ ] Sign out clears state and redirects to login
- [ ] Loading skeletons appear on every async screen
- [ ] Error states show retry button on every async screen
- [ ] Empty states show CTA on wardrobe, lookbooks, today
- [ ] No emojis anywhere in the UI
- [ ] Light theme only (no dark mode flicker)
- [ ] All interactive elements have 48px min tap target
