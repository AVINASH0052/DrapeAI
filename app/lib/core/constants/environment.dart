import 'dart:io' show Platform;

class Environment {
  Environment._();

  static const _override = String.fromEnvironment('API_BASE_URL');
  static const _prodUrl = String.fromEnvironment(
    'API_PROD_URL',
    defaultValue: 'https://api.sugatai.com',
  );

  /// Dev tunnel — only used when API_BASE_URL and prod are not set.
  static const _devTunnelUrl =
      'https://ca88-2409-40e3-2013-d1d8-715a-65b8-a699-202e.ngrok-free.app';

  static const _useProd =
      bool.fromEnvironment('USE_PROD_API', defaultValue: false);

  /// Enables the local test-token entry. It is off in every build unless
  /// explicitly supplied with --dart-define=ENABLE_DEV_TEST_FLOW=true.
  static const enableDevTestFlow = bool.fromEnvironment(
    'ENABLE_DEV_TEST_FLOW',
    defaultValue: false,
  );

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (_useProd) return _prodUrl;
    if (Platform.isIOS || Platform.isAndroid) {
      return _devTunnelUrl;
    }
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
