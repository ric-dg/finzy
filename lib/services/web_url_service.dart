import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    show urlStrategy, usePathUrlStrategy;

/// Initializes browser URL strategy for the web PWA.
///
/// Enables path-based clean URLs (e.g. `/detail` instead of `/#/detail`)
/// on web. Flutter's built-in Navigator already syncs routes with
/// [RouteSettings.name] to the URL when [usePathUrlStrategy] is active.
///
/// On non-web platforms this is a transparent no-op (flutter_web_plugins
/// stubs out every method).
class WebUrlService {
  WebUrlService._();

  static WebUrlService? _instance;

  static void init() {
    usePathUrlStrategy();
    _instance = WebUrlService._();
  }

  static WebUrlService? get instance => _instance;

  /// The current browser URL path.
  String get currentPath => urlStrategy?.getPath() ?? '/';

  /// Programmatically navigate to a URL path.
  static void navigateTo(String path) {
    urlStrategy?.pushState(null, '', path);
  }
}
