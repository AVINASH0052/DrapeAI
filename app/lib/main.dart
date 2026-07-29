import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/brand/brand.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/widgets/drape_ui.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: SugataiApp()));
}

class SugataiApp extends ConsumerWidget {
  const SugataiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return MaterialApp.router(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        // Overlay the banner so it never steals status-bar layout space.
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child ?? const SizedBox.shrink(),
            ),
            if (isOffline)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DrapeOfflineBanner(isOffline: true),
              ),
          ],
        );
      },
    );
  }
}
