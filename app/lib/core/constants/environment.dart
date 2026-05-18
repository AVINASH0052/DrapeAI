import 'dart:io' show Platform;

class Environment {
  Environment._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  // Public ngrok tunnel to the local API (works over cellular / any network).
  // Restart `ngrok http 8000` and update this URL if it changes.
  static const _tunnelUrl =
      'https://ca88-2409-40e3-2013-d1d8-715a-65b8-a699-202e.ngrok-free.app';

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    // Real iOS / Android devices use the public tunnel — works over cellular
    // and avoids iPhone Personal Hotspot's client-isolation firewall.
    if (Platform.isIOS || Platform.isAndroid) {
      return _tunnelUrl;
    }
    return 'http://localhost:8000';
  }

  /// Resolves a possibly-relative URL (e.g. "/uploads/users/x/items/y.png")
  /// against the current API base so it can be loaded as a network image.
  static String resolveUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = apiBaseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
