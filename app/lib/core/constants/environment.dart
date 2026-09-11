import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;

class Environment {
  Environment._();

  /// Explicit override — wins over everything.
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  static const _override = String.fromEnvironment('API_BASE_URL');

  static const _prodUrl = String.fromEnvironment(
    'API_PROD_URL',
    defaultValue: 'https://api.sugatai.com',
  );

  /// Optional debug-only tunnel for testing on a physical device against a
  /// laptop backend. Supply it per-run; never hardcode a tunnel URL here — a
  /// stale one silently points device builds at a dead host.
  ///   flutter run --dart-define=DEV_TUNNEL_URL=https://xxxx.ngrok-free.app
  static const _devTunnelUrl = String.fromEnvironment('DEV_TUNNEL_URL');

  /// Force the production API from a debug build.
  static const _useProd =
      bool.fromEnvironment('USE_PROD_API', defaultValue: false);

  /// Enables the local test-token entry. Off in every build unless explicitly
  /// supplied with --dart-define=ENABLE_DEV_TEST_FLOW=true, and ignored
  /// outright in release builds.
  static const _enableDevTestFlowFlag = bool.fromEnvironment(
    'ENABLE_DEV_TEST_FLOW',
    defaultValue: false,
  );

  static bool get enableDevTestFlow => kDebugMode && _enableDevTestFlowFlag;

  /// Base URL for the API.
  ///
  /// Resolution order:
  ///   1. `API_BASE_URL` override
  ///   2. production — if `USE_PROD_API=true` **or** this is a release build
  ///   3. `DEV_TUNNEL_URL`, when supplied (debug, physical device)
  ///   4. platform-appropriate localhost (debug)
  ///
  /// A release build can never fall through to a tunnel or to localhost.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (_useProd || !kDebugMode) return _prodUrl;
    if (_devTunnelUrl.isNotEmpty) return _devTunnelUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  static String resolveUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = apiBaseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
