class WebUrlService {
  WebUrlService._();

  static WebUrlService? _instance;

  static void init() {
    _instance = WebUrlService._();
  }

  static WebUrlService? get instance => _instance;

  String get currentPath => '/';

  static void navigateTo(String path) {}
}
