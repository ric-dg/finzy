import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('installPwa')
external JSAny _callInstallPwa();

@JS('isPwaInstallable')
external bool _isPwaInstallable();

class PwaInstallService {
  PwaInstallService._();

  static bool get canInstall {
    if (!kIsWeb) return false;
    return _isPwaInstallable();
  }

  static Future<bool> promptInstall() async {
    if (!kIsWeb) return false;
    if (!_isPwaInstallable()) return false;

    final result = _callInstallPwa().dartify();

    if (result is Future<bool>) {
      return await result;
    }
    if (result is Future<Object?>) {
      final value = await result;
      return value == true;
    }
    return false;
  }
}
