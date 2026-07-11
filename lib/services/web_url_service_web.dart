import 'package:flutter_web_plugins/flutter_web_plugins.dart'
    show urlStrategy, usePathUrlStrategy;

class WebUrlService {
  WebUrlService._();

  static WebUrlService? _instance;

  static void init() {
    usePathUrlStrategy();
    _instance = WebUrlService._();
  }

  static WebUrlService? get instance => _instance;

  String get currentPath => urlStrategy?.getPath() ?? '/';

  static void navigateTo(String path) {
    urlStrategy?.pushState(null, '', path);
  }
}
